class DashboardController < ApplicationController
  def index
    @total_applications = JobApplication.count
    @applied_count = JobApplication.where.not(status: "saved").count
    @interviewing_count = JobApplication.by_status("interviewing").count
    @offers_count = JobApplication.by_status("offer").count
    @rejections_count = JobApplication.by_status("rejected").count
    @status_counts = JobApplication::STATUSES.map do |status|
      { status: status, count: JobApplication.by_status(status).count }
    end
    @recent_applications = JobApplication.recent.limit(5)
    applied_total = JobApplication.where.not(status: "saved").count
    positive_responses = @interviewing_count + @offers_count
    @response_rate = applied_total > 0 ? ((positive_responses.to_f / applied_total) * 100).round(1) : 0
  end
end
