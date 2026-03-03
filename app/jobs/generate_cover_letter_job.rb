class GenerateCoverLetterJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(job_application_id, feedback: nil)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new
    return unless profile.present?
    return if job_application.job_description.blank?
    profile_text = profile.profile_text_for(job_application: job_application, limit: 10)

    skills_guidance = if job_application.has_skills_analysis?
      <<~SKILLS_GUIDANCE

        IMPORTANT - SKILLS ANALYSIS TO INCORPORATE:
        MATCHING SKILLS (weave these naturally into your examples):
        #{format_skills(job_application.matching_skills)}

        MISSING SKILLS (if relevant, acknowledge growth mindset or transferable skills):
        #{format_skills(job_application.missing_skills)}
      SKILLS_GUIDANCE
    else
      ""
    end

    previous_draft = feedback.present? ? job_application.cover_letter : nil

    service = LlmService.new
    result = service.chat_text(
      feature: :cover_letter,
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
            - Open with the specific qualification this paragraph proves
            - Provide 1-2 experiences that GAVE you this qualification
            - For each experience, state WHAT YOU LEARNED/GAINED, not just what you did
            - Connect explicitly to how this qualification prepares you for THIS role at THIS company
            - Include specific details that distinguish you from other applicants
            DO NOT start with "First, " - vary your paragraph openings.

            PARAGRAPH 3 - SECOND QUALIFICATION (unified around ONE theme):
            Structure: Qualification claim → Supporting experiences → Future application
            - Open with a different qualification relevant to the job
            - Draw from different experiences than Paragraph 2
            - Show growth or increasing responsibility over time
            - End by connecting this qualification to a specific aspect of the role or company goal
            DO NOT start with "Second, " - find a natural transition.

            PARAGRAPH 4 - CONCLUSION (1-2 sentences):
            - Express confidence directly (not "I think you'll find...")
            - Reference a specific skill and how it could contribute to a specific company goal
            - State interest in interviewing or next steps

            Sign off with:
            "Thanks,
            [First name from profile]"

            WRITING STYLE - SOUND HUMAN:
            - Vary sentence length. Mix short punchy sentences with longer ones.
            - Use contractions naturally (I'm, I've, don't) — real people use them.
            - Start some sentences with "And" or "But" occasionally.
            - Reference specific, concrete details — names of technologies, projects, numbers.
            - Avoid any phrase that sounds like a template or form letter.
            - Read it aloud — if it sounds like a robot wrote it, rewrite that sentence.
            - NO clichés: "passionate about", "excited to apply", "results-driven", "detail-oriented", "hit the ground running", "leverage my skills", "dynamic environment"
            - NEVER use "I am writing to express my interest" or similar openings.
            - Do NOT repeat achievements — each example should be unique.
            - No placeholder brackets in the final output.
            - Total length: 300-450 words.
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

            COMPANY: #{job_application.company_name}
            POSITION: #{job_application.job_title}

            JOB DESCRIPTION:
            #{job_application.job_description}

            MY EXPERIENCE LOG:
            #{profile_text}
            #{feedback.present? ? "\nPREVIOUS DRAFT:\n#{previous_draft}\n\nFEEDBACK ON PREVIOUS DRAFT (rewrite the cover letter applying these changes):\n#{feedback}" : ""}
          CONTENT
        }
      ]
    )

    if result[:error]
      job_application.record_provider_error!(feature: :cover_letter, message: result[:error])
      return
    end

    job_application.update(cover_letter: result[:content])
    job_application.check_insights_complete!
  end

  private

  def format_skills(skills_array)
    return "None provided" if skills_array.blank?

    skills_array.map do |item|
      if item.is_a?(Hash)
        detail = item["evidence"] || item["suggestion"] || item["explanation"]
        "- #{item['skill']}: #{detail}"
      else
        "- #{item}"
      end
    end.join("\n")
  end
end
