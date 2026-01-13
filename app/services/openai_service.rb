class OpenaiService
  def initialize
    @client = OpenAI::Client.new(
      api_key: Rails.application.credentials.dig(:openai, :api_key) || ENV["OPENAI_KEY"]
    )
  end

  def parse_job_posting(raw_content)
    response = @client.chat.completions.create(
      model: "gpt-4o-mini",
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

    content = response.choices.first.message.content
    JSON.parse(content)
  rescue JSON::ParserError => e
    { error: "Failed to parse response: #{e.message}" }
  rescue OpenAI::Errors::RateLimitError => e
    { error: "Rate limit exceeded. Please try again later." }
  rescue OpenAI::Errors::AuthenticationError => e
    { error: "Invalid API key. Please check your OpenAI credentials." }
  rescue OpenAI::Errors::APIError => e
    { error: "API request failed: #{e.message}" }
  rescue StandardError => e
    { error: "Unexpected error: #{e.message}" }
  end

  def generate_cover_letter(resume:, job_title:, company_name:, job_description:)
    response = @client.chat.completions.create(
      model: "gpt-4o-mini",
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are a professional cover letter writer. Write concise, compelling cover letters
            that highlight relevant experience from the resume and connect it to the job requirements.

            Guidelines:
            - Keep it to 3-4 paragraphs
            - Be specific about how the candidate's experience matches the role
            - Sound professional but personable, not generic
            - Don't use placeholder text like [Your Name] - write it as a complete letter
            - Start with a strong opening, not "I am writing to apply..."
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            Write a cover letter for this position:

            Company: #{company_name}
            Position: #{job_title}

            Job Description:
            #{job_description}

            My Resume:
            #{resume}
          CONTENT
        }
      ],
      temperature: 0.7
    )

    content = response.choices.first.message.content
    { cover_letter: content }
  rescue OpenAI::Errors::RateLimitError => e
    { error: "Rate limit exceeded. Please try again later." }
  rescue OpenAI::Errors::AuthenticationError => e
    { error: "Invalid API key. Please check your OpenAI credentials." }
  rescue OpenAI::Errors::APIError => e
    { error: "API request failed: #{e.message}" }
  rescue StandardError => e
    { error: "Unexpected error: #{e.message}" }
  end
end
