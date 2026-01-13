class DashboardController < ApplicationController
  def index
    @applications = JobApplication.recent
  end
end
