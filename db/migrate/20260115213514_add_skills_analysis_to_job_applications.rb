class AddSkillsAnalysisToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :skills_analysis, :text
  end
end
