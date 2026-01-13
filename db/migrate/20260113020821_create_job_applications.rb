class CreateJobApplications < ActiveRecord::Migration[8.1]
  def change
    create_table :job_applications do |t|
      t.string :company_name
      t.string :job_title
      t.string :location
      t.string :work_arrangement
      t.string :salary_range
      t.text :job_description
      t.text :skills
      t.string :contact_email
      t.text :application_instructions
      t.string :job_url
      t.string :status
      t.text :notes
      t.text :cover_letter
      t.datetime :applied_at
      t.datetime :followed_up_at

      t.timestamps
    end
  end
end
