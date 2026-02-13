class LlmService
  OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions".freeze
  PARSING_MODEL = "openai/gpt-oss-120b:free".freeze
  WRITING_MODEL = "z-ai/glm-4.5-air:free".freeze

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

  def generate_cover_letter(resume:, job_title:, company_name:, job_description:, skills_analysis: nil, feedback: nil, previous_cover_letter: nil)
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

            CORE PHILOSOPHY - PAST, PRESENT, FUTURE:
            Every cover letter must connect three timeframes:
            - PAST: Your experiences (education, internships, research, projects)
            - PRESENT: The qualifications those experiences gave you that make you unique NOW
            - FUTURE: How you will apply those qualifications to create value at this specific company

            CRITICAL: Focus on QUALIFICATIONS GAINED, not experiences themselves.
            BAD: "I was a research assistant with Dr. XXX and collaborated with a PhD student."
            GOOD: "As a research assistant, I developed expertise in NLP and computer vision through building a Visual Question Answering system, skills I'm eager to apply to [Company]'s image recognition challenges."

            The difference: State WHAT YOU GAINED and HOW IT APPLIES TO THE FUTURE ROLE.

            PARAGRAPH 1 - Introduction:
            - State your degree, major, institution, and graduation date
            - Identify the position you're applying for
            - Explain WHY this company matters to you personally (connect to your values or past experience)
            - End with a strong claim stating 1-2 qualifications you'll prove in the body paragraphs
            - These qualifications must directly correlate to the job description

            PARAGRAPH 2 - FIRST QUALIFICATION (unified around ONE theme):
            Structure: Qualification claim → Supporting experiences → Future application
            - Open with the specific qualification this paragraph proves (e.g., "expertise in distributed systems" or "ability to translate complex technical concepts")
            - Provide 1-2 experiences that GAVE you this qualification
            - For each experience, state WHAT YOU LEARNED/GAINED, not just what you did
            - Connect explicitly to how this qualification prepares you for THIS role at THIS company
            - Include specific details that distinguish you from other applicants with similar degrees
            DO NOT start with "First, " - vary your paragraph openings.

            PARAGRAPH 3 - SECOND QUALIFICATION (unified around ONE theme):
            Structure: Qualification claim → Supporting experiences → Future application
            - Open with a different qualification relevant to the job
            - Draw from different experiences than Paragraph 2 (education, research, internships, projects)
            - Show growth or increasing responsibility over time
            - Emphasize the UNIQUE training or approach from your program/experiences
            - End by connecting this qualification to a specific aspect of the role or company goal
            DO NOT start with "Second, " - find a natural transition.

            PARAGRAPH 4 - CONCLUSION (1-2 sentences):
            - Express confidence directly (not "I think you'll find...")
            - Reference a specific skill and how it could contribute to a specific company goal
            - State interest in interviewing or next steps

            Sign off with:
            "Thanks,
            [First name from resume]"

            RULES:
            - Be SPECIFIC: Eliminate any sentence that could be written by anyone with a similar degree
            - Every experience mentioned must include what qualification it gave you
            - Use the exact terminology from the job description
            - Use specific numbers and metrics wherever possible
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
          content: "Write a cover letter for a Software Developer Co-op at Fullscript. The role involves Ruby on Rails, testing, and infrastructure work."
        },
        {
          role: "assistant",
          content: <<~EXAMPLE
            I'm a Computer Science student at the University of Victoria, graduating in April 2027, and I'm applying for the Software Developer Co-op position at Fullscript. What stood out to me in your developer handbook was the emphasis on craftsmanship—building things carefully, understanding the full lifecycle of a product, and taking responsibility for the code you ship. That mindset closely matches how I've learned to work as a developer.

            I recently spent eight months at Leanpub contributing to a large Ruby on Rails monolith, which gave me a realistic view of maintaining and evolving a production system. Not only did I ship features quickly, I was able to help strengthen the codebase by writing and maintaining tests with RSpec and FactoryBot. I also worked on long-running processes, building a background job tracking system with Redis that kept users informed without tying up application resources. That experience taught me how to balance speed with reliability, and to treat testing as a core part of development rather than an afterthought.

            In addition to application work, I've had hands-on experience with infrastructure and performance. At Trustscience, I re-engineered a file storage system that reduced AWS S3 costs by 15%, and improved query performance by roughly 50% using DynamoDB. I'm comfortable working within real-world constraints like cloud costs and latency, and I enjoy digging into existing systems to make them leaner, faster, and easier to maintain.

            I'd be excited to bring this combination of Rails experience, infrastructure awareness, and care for code quality to the Fullscript team. Thank you for your time and consideration—I'd welcome the opportunity to speak further.
          EXAMPLE
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
            #{feedback.present? ? "\nPREVIOUS DRAFT:\n#{previous_cover_letter}\n\nFEEDBACK ON PREVIOUS DRAFT (rewrite the cover letter applying these changes):\n#{feedback}" : ""}
          CONTENT
        }
      ],
      temperature: 0.4
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
