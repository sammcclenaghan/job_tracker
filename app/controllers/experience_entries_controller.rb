class ExperienceEntriesController < ApplicationController
  before_action :set_experience_entry, only: [ :update, :destroy ]

  def create
    @experience_entry = ExperienceEntry.new(experience_entry_params)
    if @experience_entry.save
      redirect_to edit_resume_path, notice: "Experience entry added."
    else
      redirect_to edit_resume_path, alert: @experience_entry.errors.full_messages.join(", ")
    end
  end

  def update
    if @experience_entry.update(experience_entry_params)
      redirect_to edit_resume_path, notice: "Experience entry updated."
    else
      redirect_to edit_resume_path, alert: @experience_entry.errors.full_messages.join(", ")
    end
  end

  def destroy
    @experience_entry.destroy
    redirect_to edit_resume_path, notice: "Experience entry removed."
  end

  private

  def set_experience_entry
    @experience_entry = ExperienceEntry.find(params[:id])
  end

  def experience_entry_params
    params.require(:experience_entry).permit(
      :entry_type, :title, :organization, :location, :date_range, :technologies, :tags, :details
    )
  end
end
