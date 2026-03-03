class AddProjectRecommendationsAndExperienceTailoringToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :project_recommendations, :json
    add_column :job_applications, :experience_tailoring, :json
  end
end
