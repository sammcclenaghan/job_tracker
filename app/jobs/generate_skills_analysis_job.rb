class GenerateSkillsAnalysisJob < ApplicationJob
  def perform(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    resume = Resume.first
    return if resume.nil? || resume.content.blank?
    return if job_application.job_description.blank?

    service = LlmService.new
    result = service.generate_skills_analysis(
      resume: resume.content,
      job_title: job_application.job_title,
      job_description: job_application.job_description,
      required_skills: job_application.skills_list
    )

    return if result[:error] || result["error"]

    job_application.update(skills_analysis: result)
  end
end
