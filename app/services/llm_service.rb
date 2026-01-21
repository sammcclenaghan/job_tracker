class LlmService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze
  PARSING_MODEL = "openai/gpt-oss-120b:free".freeze
  WRITING_MODEL = "xiaomi/mimo-v2-flash:free".freeze

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

  def generate_skills_analysis(resume:, job_title:, job_description:, required_skills:)
    response = chat(
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an expert career coach and resume analyst. Your job is to compare a candidate's resume against a job posting and provide a detailed skills gap analysis.

            Analyze the resume against the job requirements and return a JSON object with these three categories:

            1. "matching_skills" - Array of objects for skills the candidate HAS that match job requirements
               Each object: { "skill": "skill name", "explanation": "brief explanation of where this appears in their resume and how it matches" }

            2. "skills_to_highlight" - Array of objects for skills/experiences the candidate should EMPHASIZE in their application
               Each object: { "skill": "skill/experience name", "explanation": "why this should be highlighted and how to position it" }
               These should be strategic recommendations based on what the job posting emphasizes most.

            3. "skills_to_develop" - Array of objects for skills the candidate may be MISSING or should address
               Each object: { "skill": "skill name", "explanation": "why this matters for the role and suggestions for addressing it" }
               Include suggestions like: transferable skills, quick learning opportunities, or how to acknowledge the gap positively.

            Guidelines:
            - Be specific and actionable in explanations
            - Reference specific parts of the resume when possible
            - For skills_to_highlight, focus on what would make the candidate stand out
            - For skills_to_develop, be constructive - suggest how gaps could be addressed
            - Limit each category to the most important 3-6 items
            - Return ONLY valid JSON, no markdown or extra text
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            POSITION: #{job_title}

            JOB DESCRIPTION:
            #{job_description}

            REQUIRED SKILLS FROM JOB POSTING:
            #{required_skills.join(", ")}

            CANDIDATE'S RESUME:
            #{resume}
          CONTENT
        }
      ],
      temperature: 0.4
    )

    return response if response[:error]

    JSON.parse(response[:content])
  rescue JSON::ParserError => e
    { error: "Failed to parse skills analysis: #{e.message}" }
  end

  def generate_cover_letter(resume:, job_title:, company_name:, job_description:, skills_analysis: nil)
    skills_guidance = if skills_analysis.present?
      <<~SKILLS_GUIDANCE

        IMPORTANT - SKILLS ANALYSIS TO INCORPORATE:
        You have been provided with a skills analysis. Use this to write a more targeted cover letter:

        SKILLS TO HIGHLIGHT (emphasize these prominently):
        #{format_skills_for_prompt(skills_analysis["skills_to_highlight"])}

        MATCHING SKILLS (weave these naturally into your examples):
        #{format_skills_for_prompt(skills_analysis["matching_skills"])}

        SKILLS GAPS TO ADDRESS (if relevant, acknowledge growth mindset or transferable skills):
        #{format_skills_for_prompt(skills_analysis["skills_to_develop"])}
      SKILLS_GUIDANCE
    else
      ""
    end

    response = chat(
      model: WRITING_MODEL,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an expert cover letter writer for co-op students and new graduates. Write cover letters that follow this structure:

            PARAGRAPH 1 - INTRODUCTION (2-3 sentences):
            - Identify yourself as a student: year, program, and university (from the resume)
            - Mention your internship/co-op experience count (e.g., "with three internships" or "with 12 months of industry experience")
            - State the position and team/company you're applying for
            - Lead with your most impressive relevant achievement with a specific metric
            Example: "As a third-year Computer Science co-op student at [University] with three internships under my belt, I'm applying for the [Position] at [Company]. In my most recent role, I [achievement with metric]."

            PARAGRAPH 2 - TRANSITION (1 sentence max):
            Create a brief, natural bridge to your qualifications.
            DO NOT write "There are X things that make me the perfect fit" - this sounds robotic.
            Keep this to one sentence that flows naturally into the body paragraphs.

            PARAGRAPH 3 - FIRST QUALIFICATION:
            Connect a personal trait or theme (curiosity, initiative, problem-solving) to a specific story from the resume. Include:
            - The theme/trait that drives you
            - A specific example with context
            - Concrete outcomes or skills gained
            - How this prepares you for the role
            DO NOT start with "First, " - vary your paragraph openings.

            PARAGRAPH 4 - SECOND QUALIFICATION:
            Highlight relevant technical experience. Include:
            - The type of experience you have
            - Multiple specific examples (3-4 short ones) with technologies used
            - Growth or increased responsibility over time
            DO NOT start with "Second, " - find a natural transition.

            PARAGRAPH 5 - WHY THIS COMPANY:
            Explain why you want THIS company specifically:
            - Reference a specific product, project, initiative, or news item
            - Explain WHY it matters to you personally (connect to your values or past experience)
            - Show how your skills could contribute to that specific thing
            DO NOT start with "Finally, " or "Third, ".

            PARAGRAPH 6 - CONCLUSION (1-2 sentences):
            Express confidence and enthusiasm directly. Suggest next steps.
            DO NOT write "I think you'll find..." - this sounds uncertain.
            Example: "I'd love to discuss how my experience with [skill] could contribute to [specific company goal]."

            Sign off with:
            "Thanks,
            [First name from resume]"

            RULES:
            - Write like a person, not a template. Read it aloud - if it sounds robotic, rewrite it.
            - Use specific numbers and metrics wherever possible
            - Use the same terminology as the job description
            - Keep it conversational but professional
            - VARY sentence openings - do not start more than 2 consecutive sentences with "I"
            - AVOID clichés: "passionate about", "excited to apply", "results-driven", "detail-oriented", "hit the ground running"
            - Do NOT repeat achievements - each example should be unique
            - No placeholder brackets in the final output - fill everything in
            - Total length: 300-450 words
            #{skills_guidance}
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

    { cover_letter: clean_text(response[:content]) }
  end

  private

  def format_skills_for_prompt(skills_array)
    return "None provided" if skills_array.blank?

    skills_array.map do |item|
      if item.is_a?(Hash)
        "- #{item['skill']}: #{item['explanation']}"
      else
        "- #{item}"
      end
    end.join("\n")
  end

  def clean_text(text)
    return text if text.nil?

    text
      .gsub("‑", "-")           # non-breaking hyphen to regular hyphen
      .gsub("–", "-")           # en-dash to hyphen
      .gsub("—", "-")           # em-dash to hyphen
      .gsub(" %", "%")          # remove space before percent
      .gsub(" ,", ",")          # remove space before comma
      .gsub(/\*\*([^*]+)\*\*/, '\1')  # remove markdown bold
      .gsub(/\*([^*]+)\*/, '\1')      # remove markdown italic
      .gsub(/^- /, "• ")        # convert markdown bullets to bullet character
      .strip
  end

  def chat(messages:, model: PARSING_MODEL, temperature: 0.7)
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
        model: model,
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
