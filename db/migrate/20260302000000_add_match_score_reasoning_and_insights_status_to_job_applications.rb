class AddMatchScoreReasoningAndInsightsStatusToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :match_score_reasoning, :text
    add_column :job_applications, :insights_status, :string, default: "pending"
  end
end
