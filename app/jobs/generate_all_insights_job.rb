class GenerateAllInsightsJob < ApplicationJob
  queue_as :default

  def perform(job_application_id)
    job_application = JobApplication.find_by(id: job_application_id)
    return unless job_application

    profile = ExperienceProfileService.new
    return unless profile.present?
    return if job_application.job_description.blank?

    job_application.update(insights_status: "processing")
    job_application.clear_provider_errors!

    # Auto-run only the core insights (cover letter stays manual)
    GenerateMatchScoreJob.perform_later(job_application_id)
    GenerateProjectRecommendationsJob.perform_later(job_application_id)
    GenerateExperienceTailoringJob.perform_later(job_application_id)
  end
end
