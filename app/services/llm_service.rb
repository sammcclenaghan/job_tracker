class LlmService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze
  MODEL = "openai/gpt-oss-120b:free".freeze

  def initialize
    @api_key = Rails.application.credentials.openrouter.api_key
  end

  def parse_job_posting(raw_content)
    response = chat(
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
        {
          role: "user",
          content: raw_content
        }
      ],
      temperature: 0.3
    )

    return response if response[:error]

    JSON.parse(response[:content])
  rescue JSON::ParserError => e
    { error: "Failed to parse response: #{e.message}" }
  end

  def generate_cover_letter(resume:, job_title:, company_name:, job_description:)
    response = chat(
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an expert cover letter writer. Write cover letters that follow this EXACT structure:

            PARAGRAPH 1 - INTRODUCTION (2 sentences):
            Sentence 1: "I am a [2-3 descriptive adjectives] [Current/Target Role] with [X years] of experience interested in learning more about [Company]'s [Team/Department from job posting]."
            Sentence 2: "Over the last [time period], I've [major achievement with specific number/metric] by [how you did it] and also [secondary achievement or side project]."

            PARAGRAPH 2 - TRANSITION (1-2 sentences):
            "And now I'm excited to continue my journey by contributing and growing at [Company]. There are [two/three] things that make me the perfect fit for this position:"

            PARAGRAPH 3 - FIRST QUALIFICATION:
            Start with "First, " then connect a personal trait or theme (curiosity, initiative, leadership) to a specific story from the resume. Include:
            - The theme/trait that drives you
            - A specific example with context
            - Concrete outcomes or skills gained
            - How this helps you in the role

            PARAGRAPH 4 - SECOND QUALIFICATION:
            Start with "Second, " then highlight relevant experience. Include:
            - The type of experience you have
            - Multiple specific examples (3-4 short ones)
            - Growth or increased responsibility over time

            PARAGRAPH 5 - WHY THIS COMPANY:
            Start with "Finally, " or "Third, " then explain why you want THIS company:
            - Reference their vision, values, or culture (and why it resonates personally)
            - Mention industry interest or recent company news
            - Connect it back to your background or interests

            PARAGRAPH 6 - CONCLUSION (2 sentences):
            "I think you'll find that my experience is a really good fit for [Company] and specifically this position. I'm ready to take my skills to the next level with your team and look forward to hearing back."

            Sign off with:
            "Thanks,
            [First name from resume]"

            RULES:
            - Use specific numbers and metrics wherever possible
            - Use the same terminology as the job description
            - Keep it conversational but professional
            - No placeholder brackets in the final output - fill everything in
            - Total length: 300-450 words
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            Write a cover letter following the exact structure provided.

            COMPANY: #{company_name}
            POSITION: #{job_title}

            JOB DESCRIPTION:
            #{job_description}

            MY RESUME:
            #{resume}
          CONTENT
        }
      ],
      temperature: 0.7
    )

    return response if response[:error]

    { cover_letter: response[:content] }
  end

  private

  def chat(messages:, temperature: 0.7)
    conn = Faraday.new(url: OPENROUTER_URL) do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    response = conn.post do |req|
      req.headers["Authorization"] = "Bearer #{@api_key}"
      req.headers["Content-Type"] = "application/json"
      req.headers["HTTP-Referer"] = "http://localhost:3000"
      req.headers["X-Title"] = "Job Tracker"
      req.body = {
        model: MODEL,
        messages: messages,
        temperature: temperature
      }.to_json
    end

    if response.success?
      body = response.body
      content = body.dig("choices", 0, "message", "content")
      { content: content }
    else
      error_message = response.body.dig("error", "message") || "Request failed with status #{response.status}"
      { error: error_message }
    end
  rescue Faraday::Error => e
    { error: "API request failed: #{e.message}" }
  rescue StandardError => e
    { error: "Unexpected error: #{e.message}" }
  end
end
