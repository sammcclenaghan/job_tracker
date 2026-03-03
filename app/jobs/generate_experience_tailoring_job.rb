class GenerateExperienceTailoringJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new(entries: ExperienceEntry.where(entry_type: "experience").recent)
    return unless profile.present?
    return if job_application.job_description.blank?
    profile_text = profile.profile_text_for(job_application: job_application, limit: 10)

    service = LlmService.new
    result = service.chat_json(
      feature: :experience_tailoring,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an aggressive resume experience writer.
            Your job is to pick the candidate's BEST experience points for the target position and rewrite them into punchy, impressive bullets using Google's X-Y-Z formula.

            You are a creative writer, not an editor. Do not just rearrange the original words. Completely rewrite each bullet from scratch so it leads with impact and sounds impressive. You may infer reasonable metrics, percentages, or scale if the original doesn't provide them - a resume is a marketing document and plausible numbers are expected.

            ## Google X-Y-Z Formula
            Every bullet MUST follow this structure:
              "[X - what you accomplished/the result], [Y - measured by/evidence], by [Z - how you did it]"

            The result (X) comes FIRST. The method (Z) comes LAST. This is non-negotiable.

            ### Good X-Y-Z examples (study the structure):
            - "Reduced page load time by 40% for 2M monthly users by migrating image pipeline to a lazy-loading CDN architecture"
            - "Automated monthly sales reporting for a 50-person team by building a Python ETL pipeline pulling from Salesforce and PostgreSQL"
            - "Improved test reliability from 72% to 95% pass rate by refactoring flaky integration tests and adding retry logic for network-dependent specs"
            - "Cut customer onboarding time from 3 days to 4 hours by building a self-serve setup wizard with React and a step-validation API"
            - "Eliminated manual deployment errors across 12 microservices by designing a CI/CD pipeline with GitHub Actions and Docker"

            ### Bad examples (do NOT produce bullets like these):
            - "Responsible for backend development" (no X, no Y, no Z)
            - "Leveraged cutting-edge technologies to deliver robust, scalable solutions" (buzzword soup)
            - "Added containerized execution using Apple container CLI" (method first, no result - this is Z-first, not X-first)
            - "Integrated RubyLLM agent tool-calling so the model can inspect directories" (just describes what was done, no impact)

            ## Selection strategy
            For each role in the experience log, pick EXACTLY 2 bullet points - the two that are most relevant to the target position. Ignore the rest. Quality over quantity.

            Choose bullets that:
            - Overlap with skills or responsibilities in the job description
            - Have the most impressive or tangible outcomes
            - Can be rewritten to sound strong for this specific role

            ## Output format
            Return a JSON object with an array called "jobs", where each entry represents a job/role:

            Each object in "jobs":
            { "company": "company name", "title": "job title", "bullets": [
              { "original": "the original bullet (can be summarized)", "tailored": "completely rewritten bullet in X-Y-Z format", "change_summary": "why this bullet was picked and what changed" }
            ]}

            ## Writing rules
            - Lead with the result or impact, ALWAYS
            - Include a metric or measure - infer a plausible one if the original lacks it
            - End with the method/approach/tools used
            - Use language that aligns with the target job description where it fits naturally
            - Keep bullets concise: one sentence, roughly 18-30 words
            - No buzzwords: "leveraged", "synergy", "robust", "spearheaded", "cutting-edge"
            - Only include roles that appear in the experience log
            - EXACTLY 2 bullets per role, no more, no less
            - `change_summary` should be <= 12 words
            - Return ONLY valid JSON, no markdown or extra text
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            TARGET POSITION: #{job_application.job_title} at #{job_application.company_name}

            JOB DESCRIPTION:
            #{job_application.job_description}

            REQUIRED SKILLS:
            #{job_application.skills_list.join(", ")}

            CANDIDATE EXPERIENCE LOG:
            #{profile_text}
          CONTENT
        }
      ]
    )

    if result[:error]
      job_application.record_provider_error!(feature: :experience_tailoring, message: result[:error])
      return
    end

    job_application.update(experience_tailoring: normalize_experience_tailoring(result))
    job_application.check_insights_complete!
  end

  private

  def normalize_experience_tailoring(result)
    jobs = (result["jobs"] || []).map do |job|
      bullets = (job["bullets"] || []).map do |bullet|
        {
          "original" => clean_bullet_text(bullet["original"]),
          "tailored" => clean_bullet_text(bullet["tailored"]),
          "change_summary" => bullet["change_summary"].to_s.strip
        }
      end

      {
        "company" => job["company"],
        "title" => job["title"],
        "bullets" => bullets
      }
    end

    { "jobs" => jobs }
  end

  def clean_bullet_text(text)
    s = text.to_s.strip
    s = s.sub(/\A[•\-]\s*/, "")
    s = s.sub(/\A\[(.*)\]\z/, '\1')
    s.strip
  end
end
