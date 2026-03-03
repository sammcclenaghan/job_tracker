class LlmService
  PARSING_MODEL = "openai/gpt-oss-120b:free".freeze
  WRITING_MODEL = "meta-llama/llama-3.3-70b-instruct:free".freeze
  DEFAULT_OLLAMA_MODEL = "glm4".freeze

  PROVIDERS = %w[openrouter ollama].freeze
  FEATURES = %w[
    parsing
    skills_analysis
    match_score
    cover_letter
    project_recommendations
    experience_tailoring
  ].freeze
  DEFAULT_OLLAMA_URL = "http://localhost:11434".freeze

  def initialize
    @openrouter_api_key = Setting.get("openrouter_api_key").presence ||
      Rails.application.credentials.openrouter.api_key
    @ollama_base_url = Setting.get("ollama_base_url").presence || DEFAULT_OLLAMA_URL
    @ollama_model = Setting.get("ollama_model").presence || DEFAULT_OLLAMA_MODEL
  end

  def self.provider_for(feature)
    Setting.get("provider_#{feature}") || "openrouter"
  end

  def self.model_for(feature)
    provider = provider_for(feature)
    custom_model = Setting.get("model_#{feature}").presence
    return custom_model if custom_model

    default_model_for(feature, provider: provider)
  end

  def self.default_model_for(feature, provider:)
    return Setting.get("ollama_model").presence || DEFAULT_OLLAMA_MODEL if provider == "ollama"

    feature.to_s == "cover_letter" ? WRITING_MODEL : PARSING_MODEL
  end

  # Returns parsed JSON hash or { error: "..." }
  def chat_json(feature:, messages:, model: nil, temperature: 0.3)
    response = chat(feature: feature, messages: messages, model: model, temperature: temperature, json: true)
    return response if response[:error]

    JSON.parse(strip_markdown_fences(response[:content]))
  rescue JSON::ParserError => e
    { error: "Failed to parse response: #{e.message}" }
  end

  # Returns { content: "..." } or { error: "..." }
  def chat_text(feature:, messages:, model: nil, temperature: 0.4)
    response = chat(feature: feature, messages: messages, model: model, temperature: temperature)
    return response if response[:error]

    { content: clean_text(response[:content]) }
  end

  # Parse a raw job posting into structured data
  def parse_job_posting(raw_content)
    chat_json(
      feature: :parsing,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are a job posting parser. Extract structured information from job postings.
            Return a JSON object with these fields (use null for missing data):
            - company_name (string)
            - job_title (string)
            - location (string)
            - work_arrangement (string: "remote", "hybrid", or "onsite")
            - salary_range (string)
            - job_description (string: the main description/responsibilities)
            - skills (array of strings: required skills/technologies)
            - contact_email (string)
            - application_instructions (string)
            - job_url (string)

            Return ONLY valid JSON, no markdown or extra text.
          PROMPT
        },
        { role: "user", content: raw_content }
      ]
    )
  end

  private

  def strip_markdown_fences(text)
    return text if text.nil?
    text.sub(/\A\s*```\w*\n?/, "").sub(/\n?```\s*\z/, "").strip
  end

  def clean_text(text)
    return text if text.nil?
    text
      .gsub("‑", "-")
      .gsub("–", "-")
      .gsub("—", "-")
      .gsub(" %", "%")
      .gsub(" ,", ",")
      .gsub(/\*\*([^*]+)\*\*/, '\1')
      .gsub(/\*([^*]+)\*/, '\1')
      .gsub(/^- /, "• ")
      .strip
  end

  def chat(feature:, messages:, model: nil, temperature: 0.7, json: false)
    provider = self.class.provider_for(feature)
    selected_model = model.presence || self.class.model_for(feature)

    if provider == "ollama"
      chat = build_chat(provider: :ollama, model: selected_model, temperature: temperature)
    else
      chat = build_chat(provider: :openrouter, model: selected_model, temperature: temperature)
    end

    return { error: "No messages provided" } if messages.blank?

    chat = chat.with_params(response_format: { type: "json_object" }) if json

    messages[0...-1].each do |message|
      chat.add_message(role: message[:role].to_sym, content: message[:content])
    end

    last_message = messages.last
    response = chat.ask(last_message[:content])
    { content: response.content }
  rescue Faraday::ConnectionFailed
    return { error: "Cannot connect to Ollama at #{@ollama_base_url}. Is Ollama running?" } if provider == "ollama"
    { error: "API request failed (provider=#{provider}, model=#{selected_model}): Connection failed" }
  rescue RubyLLM::Error => e
    { error: format_provider_error(provider: provider, model: selected_model, error: e) }
  rescue StandardError => e
    { error: "Unexpected error (provider=#{provider}, model=#{selected_model}): #{e.message}" }
  end

  def build_chat(provider:, model:, temperature:)
    context = RubyLLM.context do |config|
      config.logger = Rails.logger

      if provider == :openrouter
        config.openrouter_api_key = @openrouter_api_key
      else
        config.ollama_api_base = normalize_ollama_base(@ollama_base_url)
        config.ollama_api_key = ENV["OLLAMA_API_KEY"] if ENV["OLLAMA_API_KEY"].present?
      end
    end

    chat = context.chat(model: model, provider: provider, assume_model_exists: true)
    chat.with_temperature(temperature)
  end

  def normalize_ollama_base(base_url)
    base = base_url.to_s
    return "#{DEFAULT_OLLAMA_URL}/v1" if base.blank?
    base.end_with?("/v1") ? base : "#{base}/v1"
  end

  def format_provider_error(provider:, model:, error:)
    status = error.response&.status
    body = error.response&.body
    parsed_message = extract_provider_error_message(body)
    message = parsed_message.presence || error.message

    formatted = +"API request failed (provider=#{provider}, model=#{model}"
    formatted << ", status=#{status}" if status.present?
    formatted << "): #{message}"

    if provider == "openrouter" && message.to_s.include?("Provider returned error")
      formatted << ". OpenRouter upstream provider failed for this model; try a different model for this feature."
    end

    formatted
  end

  def extract_provider_error_message(body)
    case body
    when Hash
      error = body["error"]
      return error if error.is_a?(String)
      return unless error.is_a?(Hash)

      parts = []
      parts << error["message"] if error["message"].present?
      parts << "code=#{error['code']}" if error["code"].present?
      parts << "type=#{error['type']}" if error["type"].present?
      metadata = error["metadata"]
      if metadata.is_a?(Hash)
        parts << "provider=#{metadata['provider_name']}" if metadata["provider_name"].present?
        parts << "raw=#{metadata['raw']}" if metadata["raw"].present?
      end
      parts.compact_blank.join(", ")
    when String
      body
    end
  end
end
