require "test_helper"

class LlmServiceTest < ActiveSupport::TestCase
  setup do
    @service = LlmService.new
  end

  test "FEATURES includes all insight feature keys" do
    expected = %w[
      parsing
      skills_analysis
      match_score
      cover_letter
      project_recommendations
      experience_tailoring
    ]

    assert_equal expected.sort, LlmService::FEATURES.sort
  end

  test "model_for returns feature-specific model override when configured" do
    Setting.set("provider_skills_analysis", "openrouter")
    Setting.set("model_skills_analysis", "anthropic/claude-3.5-sonnet")

    assert_equal "anthropic/claude-3.5-sonnet", LlmService.model_for("skills_analysis")
  end

  test "model_for falls back to provider defaults" do
    Setting.set("model_parsing", nil)
    Setting.set("ollama_model", nil)
    Setting.set("provider_parsing", "openrouter")
    Setting.set("provider_cover_letter", "openrouter")
    Setting.set("provider_experience_tailoring", "ollama")

    assert_equal LlmService::PARSING_MODEL, LlmService.model_for("parsing")
    assert_equal LlmService::WRITING_MODEL, LlmService.model_for("cover_letter")
    assert_equal LlmService::DEFAULT_OLLAMA_MODEL, LlmService.model_for("experience_tailoring")
  end

  test "model_for uses global ollama_model when ollama feature model is unset" do
    Setting.set("provider_experience_tailoring", "ollama")
    Setting.set("model_experience_tailoring", nil)
    Setting.set("ollama_model", "glm-5")

    assert_equal "glm-5", LlmService.model_for("experience_tailoring")
  end

  test "chat_json uses configured per-feature model for openrouter" do
    Setting.set("provider_skills_analysis", "openrouter")
    Setting.set("model_skills_analysis", "openai/gpt-4o-mini")
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .with { |req| JSON.parse(req.body)["model"] == "openai/gpt-4o-mini" }
      .to_return(
        status: 200,
        body: { choices: [ { message: { content: { ok: true }.to_json } } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.chat_json(
      feature: :skills_analysis,
      messages: [
        { role: "system", content: "System prompt" },
        { role: "user", content: "User prompt" }
      ]
    )

    assert_equal true, result["ok"]
  end

  test "chat_json uses configured per-feature model for ollama" do
    Setting.set("provider_parsing", "ollama")
    Setting.set("model_parsing", "llama3.2")
    Setting.set("ollama_base_url", "http://localhost:11434")
    stub_request(:post, "http://localhost:11434/v1/chat/completions")
      .with { |req| JSON.parse(req.body)["model"] == "llama3.2" }
      .to_return(
        status: 200,
        body: { choices: [ { message: { content: { ok: true }.to_json } } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.chat_json(
      feature: :parsing,
      messages: [
        { role: "system", content: "System prompt" },
        { role: "user", content: "User prompt" }
      ]
    )

    assert_equal true, result["ok"]
  end

  # parse_job_posting tests
  test "parse_job_posting returns parsed data on success" do
    response_json = {
      company_name: "Test Corp",
      job_title: "Ruby Developer",
      location: "Remote",
      work_arrangement: "remote",
      salary_range: "$100k-$150k",
      job_description: "Build great software",
      skills: [ "Ruby", "Rails", "PostgreSQL" ],
      contact_email: "jobs@test.com",
      application_instructions: "Apply online",
      job_url: "https://test.com/jobs/1"
    }.to_json

    stub_openrouter_success(response_json)

    result = @service.parse_job_posting("Some job posting text")

    assert_equal "Test Corp", result["company_name"]
    assert_equal "Ruby Developer", result["job_title"]
    assert_equal [ "Ruby", "Rails", "PostgreSQL" ], result["skills"]
  end

  test "parse_job_posting returns error on API failure" do
    stub_openrouter_error(message: "Rate limit exceeded", status: 429)

    result = @service.parse_job_posting("Some job posting text")

    assert result[:error]
    assert_includes result[:error], "Rate limit exceeded"
  end

  test "parse_job_posting returns error on invalid JSON response" do
    stub_openrouter_success("This is not valid JSON {{{")

    result = @service.parse_job_posting("Some job posting text")

    assert result[:error]
    assert_includes result[:error], "Failed to parse response"
  end

  # chat_json tests
  test "chat_json returns parsed JSON" do
    response_json = {
      matching_skills: [
        { skill: "Ruby", evidence: "5 years experience" }
      ],
      missing_skills: [
        { skill: "Kubernetes", suggestion: "Consider certification" }
      ]
    }.to_json

    stub_openrouter_success(response_json)

    result = @service.chat_json(
      feature: :skills_analysis,
      messages: [
        { role: "system", content: "You are a skills matcher." },
        { role: "user", content: "Analyze this resume." }
      ]
    )

    assert_kind_of Array, result["matching_skills"]
    assert_kind_of Array, result["missing_skills"]
  end

  test "chat_json returns error on API failure" do
    stub_openrouter_error(message: "Service unavailable", status: 503)

    result = @service.chat_json(
      feature: :skills_analysis,
      messages: [
        { role: "system", content: "System prompt" },
        { role: "user", content: "User prompt" }
      ]
    )

    assert result[:error]
  end

  test "chat_json returns error on invalid JSON" do
    stub_openrouter_success("not json")

    result = @service.chat_json(
      feature: :skills_analysis,
      messages: [
        { role: "system", content: "System prompt" },
        { role: "user", content: "User prompt" }
      ]
    )

    assert result[:error]
    assert_includes result[:error], "Failed to parse response"
  end

  # chat_text tests
  test "chat_text returns cleaned text" do
    text = "Dear Hiring Manager,\n\nI am **excited** to apply..."

    stub_openrouter_success(text)

    result = @service.chat_text(
      feature: :cover_letter,
      messages: [
        { role: "system", content: "Write a cover letter." },
        { role: "user", content: "Write one for this job." }
      ]
    )

    assert result[:content]
    assert_not_includes result[:content], "**"
  end

  test "chat_text handles special characters" do
    text_with_specials = "Use em\u2014dash and en\u2013dash and 50 % and ** bold **"

    stub_openrouter_success(text_with_specials)

    result = @service.chat_text(
      feature: :cover_letter,
      messages: [
        { role: "system", content: "Write." },
        { role: "user", content: "Write something." }
      ]
    )

    content = result[:content]
    assert_not_includes content, "\u2014"
    assert_not_includes content, "\u2013"
    assert_not_includes content, " %"
  end

  test "chat_text returns error on API failure" do
    stub_openrouter_error(message: "Timeout", status: 504)

    result = @service.chat_text(
      feature: :cover_letter,
      messages: [
        { role: "system", content: "Write." },
        { role: "user", content: "Write something." }
      ]
    )

    assert result[:error]
  end

  # Network error handling
  test "handles connection errors" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    result = @service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "API request failed"
  end

  test "handles unexpected errors" do
    stub_request(:post, "https://openrouter.ai/api/v1/chat/completions")
      .to_raise(StandardError.new("Something unexpected"))

    result = @service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "Unexpected error"
  end

  # Ollama provider tests
  test "uses ollama provider when configured" do
    response_json = { company_name: "Ollama Corp", job_title: "Dev" }.to_json
    stub_ollama_success(response_json)

    service = LlmService.new
    result = service.parse_job_posting("Some job posting text")

    assert_equal "Ollama Corp", result["company_name"]
  end

  test "ollama returns error on API failure" do
    stub_ollama_error(message: "Model not found", status: 404)

    service = LlmService.new
    result = service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "Model not found"
  end

  test "ollama returns friendly error when connection refused" do
    set_all_providers("ollama")
    Setting.set("ollama_base_url", "http://localhost:11434")
    Setting.set("ollama_model", "glm4")
    stub_request(:post, "http://localhost:11434/v1/chat/completions")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    service = LlmService.new
    result = service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "Cannot connect to Ollama"
  end

  test "ollama chat_text works" do
    stub_ollama_success("Dear Hiring Manager, I am applying...")

    service = LlmService.new
    result = service.chat_text(
      feature: :cover_letter,
      messages: [
        { role: "system", content: "Write a cover letter." },
        { role: "user", content: "Write one." }
      ]
    )

    assert result[:content]
  end
end
