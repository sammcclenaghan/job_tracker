class GenerateSkillsAnalysisJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new
    return unless profile.present?
    return if job_application.job_description.blank?
    profile_text = profile.profile_text_for(job_application: job_application, limit: 8)

    service = LlmService.new
    result = service.chat_json(
      feature: :skills_analysis,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are a skills matcher. Compare a candidate's experience log against a job posting.

            Return a JSON object with exactly two arrays:

            1. "matching_skills" - Skills the candidate HAS that the job requires
               Each object: { "skill": "skill name", "evidence": "where this appears in their experience log" }

            2. "missing_skills" - Skills the job requires that the candidate LACKS
               Each object: { "skill": "skill name", "suggestion": "how to address this gap" }

            Guidelines:
            - Only include skills explicitly mentioned or clearly demonstrated in the experience log
            - For missing_skills, suggest transferable skills or quick ways to address the gap
            - Limit each category to the most important 4-8 items
            - Return ONLY valid JSON, no markdown or extra text
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            POSITION: #{job_application.job_title}

            JOB DESCRIPTION:
            #{job_application.job_description}

            REQUIRED SKILLS FROM JOB POSTING:
            #{job_application.skills_list.join(", ")}

            CANDIDATE EXPERIENCE LOG:
            #{profile_text}
          CONTENT
        }
      ]
    )

    if result[:error]
      job_application.record_provider_error!(feature: :skills_analysis, message: result[:error])
      return
    end

    job_application.update(skills_analysis: result)
    job_application.check_insights_complete!
  end
end
