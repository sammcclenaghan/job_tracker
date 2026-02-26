class AddProviderErrorToJobApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :job_applications, :provider_error, :text
  end
end
