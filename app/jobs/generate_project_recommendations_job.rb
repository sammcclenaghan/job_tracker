class GenerateProjectRecommendationsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new(entries: ExperienceEntry.where(entry_type: "project").recent)
    return unless profile.present?
    return if job_application.job_description.blank?
    profile_text = profile.profile_text_for(job_application: job_application, limit: 10)

    service = LlmService.new
    result = service.chat_json(
      feature: :project_recommendations,
      messages: [
        {
          role: "system",
          content: <<~PROMPT
            You are an aggressive resume strategist and bullet-point writer.
            Given a candidate's projects and a job posting, decide which projects are most relevant, which to cut, and what's missing. Then write punchy resume bullets for each using Google's X-Y-Z formula.

            ## Google X-Y-Z Formula
            Every resume bullet MUST follow this structure:
              "[X - what you accomplished/the result], [Y - measured by/evidence], by [Z - how you did it]"

            The result (X) comes FIRST. The method (Z) comes LAST. This is non-negotiable.

            You are a creative writer, not an editor. Completely rewrite project descriptions from scratch so they lead with impact. You may infer reasonable metrics, percentages, or scale - a resume is a marketing document and plausible numbers are expected.

            ### Good X-Y-Z examples (study the structure):
            - "Reduced API response times by 60% across 15 endpoints by implementing Redis caching and query optimization in a Rails API"
            - "Shipped a real-time collaboration editor supporting 50 concurrent users by building a WebSocket layer with operational transforms"
            - "Cut deployment failures to zero for a 4-service architecture by designing a CI/CD pipeline with GitHub Actions and Docker"

            ### Bad examples (do NOT produce bullets like these):
            - "Built a web app using React and Node" (no result, no measure)
            - "Leveraged modern technologies to create a scalable platform" (buzzword soup)
            - "Implemented WebSocket support for real-time features" (method first, no impact)

            ## Output format
            Return a JSON object with:

            1. "highlight" - Projects most relevant to the target role (pick the best 2-3)
               Each object: {
                 "project": "project name from candidate log",
                 "reason": "one sentence on why this project matters for this role",
                 "talking_points": ["specific angle to emphasize in interviews", "another angle"],
                 "resume_bullets": ["X-Y-Z bullet 1", "X-Y-Z bullet 2"]
               }

            2. "deprioritize" - Projects less relevant for this specific role
               Each object: {
                 "project": "project name from candidate log",
                 "reason": "why this is less relevant",
                 "alternative": "what kind of project would be better in this slot",
                 "resume_bullets": ["X-Y-Z bullet 1", "X-Y-Z bullet 2"]
               }

            3. "missing" - Project ideas the candidate should build to strengthen their application (1-2 max)
               Each object: {
                 "idea": "brief project description",
                 "skills_demonstrated": ["skill1", "skill2"],
                 "reason": "why this would help for this role",
                 "resume_bullets": ["X-Y-Z bullet 1", "X-Y-Z bullet 2"]
               }

            ## Writing rules
            - Lead every bullet with the result or impact, ALWAYS
            - Include a metric or measure - infer a plausible one if the project lacks it
            - End with the method/approach/tools used
            - Use language that aligns with the target job description where it fits naturally
            - Keep bullets concise: one sentence, roughly 18-30 words
            - No buzzwords: "leveraged", "synergy", "robust", "spearheaded", "cutting-edge"
            - EXACTLY 2 bullets per project, no more, no less
            - Reference actual project names from the candidate's log
            - Return ONLY valid JSON, no markdown or extra text
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

            CANDIDATE PROJECTS:
            #{profile_text}
          CONTENT
        }
      ]
    )

    if result[:error]
      job_application.record_provider_error!(feature: :project_recommendations, message: result[:error])
      return
    end

    job_application.update(project_recommendations: result)
    job_application.check_insights_complete!
  end
end
