class SkillsInsightsController < ApplicationController
  def index
    @top_skills = JobApplication.top_skills(limit: 30)
    @total_applications = JobApplication.count
    @applications_with_skills = JobApplication.where.not(skills: [nil, "", "[]"]).count
  end
end
