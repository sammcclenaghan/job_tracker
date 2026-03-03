class ResumesController < ApplicationController
  def show
    @entries = ExperienceEntry.recent
  end

  def edit
    @entries = ExperienceEntry.recent
    @experience_entry = ExperienceEntry.new
  end

  def update
    redirect_to edit_resume_path, alert: "Use the experience log form to add or edit entries."
  end
end
