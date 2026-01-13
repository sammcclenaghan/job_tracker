class DashboardController < ApplicationController
  def index
    @applications = JobApplication.recent
    @applications = @applications.by_status(params[:status]) if params[:status].present?
    @current_status = params[:status]
  end
end
