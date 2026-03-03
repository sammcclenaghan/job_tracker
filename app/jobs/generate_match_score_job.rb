class GenerateMatchScoreJob < ApplicationJob
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
            You are a job match scorer. Given a candidate's experience log and a job posting, provide a match score from 0-100 and detailed reasoning.

            Return a JSON object with:
            - "score" (integer 0-100): How well the candidate matches this role
            - "reasoning" (string): 2-3 sentences explaining the score, highlighting key strengths and gaps

            Scoring guidelines:
            - 80-100: Strong match — candidate has most required skills and relevant experience
            - 60-79: Good match — candidate has many skills but some gaps
            - 40-59: Moderate match — candidate has transferable skills but significant gaps
            - 20-39: Weak match — candidate lacks most required skills
            - 0-19: Poor match — very little overlap

            Return ONLY valid JSON.
          PROMPT
        },
        {
          role: "user",
          content: <<~CONTENT
            POSITION: #{job_application.job_title} at #{job_application.company_name}

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
      job_application.record_provider_error!(feature: :match_score, message: result[:error])
      return
    end

    job_application.update(
      match_score: result["score"],
      match_score_reasoning: result["reasoning"]
    )

    job_application.check_insights_complete!
  end
end
