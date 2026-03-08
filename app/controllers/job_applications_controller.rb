class JobApplicationsController < ApplicationController
  before_action :set_job_application, only: [
    :show, :edit, :update, :destroy, :update_status,
    :regenerate_cover_letter, :regenerate_insights, :download_cover_letter
  ]

  def show
  end

  def new
    @job_application = JobApplication.new
  end

  def new_from_paste
    @job_application = JobApplication.new
  end

  def create
    @job_application = JobApplication.new(job_application_params)
    if @job_application.save
      GenerateAllInsightsJob.perform_later(@job_application.id)
      redirect_to @job_application, notice: "Job application was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def create_from_paste
    raw_content = params[:raw_content]
    if raw_content.blank?
      @job_application = JobApplication.new
      flash.now[:alert] = "Please paste a job posting"
      return render :new_from_paste, status: :unprocessable_entity
    end

    service = LlmService.new
    result = service.parse_job_posting(raw_content)
    if result[:error]
      @job_application = JobApplication.new
      flash.now[:alert] = result[:error]
      return render :new_from_paste, status: :unprocessable_entity
    end

    @job_application = JobApplication.new(
      company_name: result["company_name"],
      job_title: result["job_title"],
      location: result["location"],
      work_arrangement: result["work_arrangement"],
      salary_range: result["salary_range"],
      job_description: result["job_description"],
      skills: result["skills"],
      contact_email: result["contact_email"],
      application_instructions: result["application_instructions"],
      job_url: result["job_url"]
    )

    if @job_application.save
      GenerateAllInsightsJob.perform_later(@job_application.id)
      redirect_to @job_application, notice: "Application created! Generating insights in the background..."
    else
      flash.now[:alert] = "Failed to save: #{@job_application.errors.full_messages.join(", ")}"
      render :new_from_paste, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @job_application.update(job_application_params)
      redirect_to @job_application, notice: "Job application was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def update_status
    if @job_application.update(status: params[:status])
      @job_application.update(applied_at: Time.current) if params[:status] == "applied" && @job_application.applied_at.nil?

      respond_to do |format|
        format.json { head :ok }
        format.html { redirect_to @job_application, notice: "Status updated to #{params[:status].capitalize}" }
      end
    else
      respond_to do |format|
        format.json { head :unprocessable_entity }
        format.html { redirect_to @job_application, alert: "Failed to update status" }
      end
    end
  end

  def regenerate_cover_letter
    profile = ExperienceProfileService.new
    unless profile.present?
      redirect_to @job_application, alert: "Please add your experience log first."
      return
    end

    feedback = params[:feedback].presence
    GenerateCoverLetterJob.perform_later(@job_application.id, feedback: feedback)
    redirect_to @job_application, notice: "Regenerating cover letter..."
  end

  def download_cover_letter
    unless @job_application.cover_letter.present?
      redirect_to @job_application, alert: "Generate a cover letter first."
      return
    end

    service = CoverLetterPdfService.new(@job_application)
    pdf_data = service.generate
    send_data pdf_data, filename: service.filename, type: "application/pdf", disposition: "attachment"
  rescue => e
    redirect_to @job_application, alert: "PDF generation failed: #{e.message}"
  end

  def regenerate_insights
    GenerateAllInsightsJob.perform_later(@job_application.id)
    redirect_to @job_application, notice: "Regenerating all insights..."
  end

  def destroy
    @job_application.destroy
    redirect_to root_path, notice: "Job application was successfully deleted."
  end

  private

  def set_job_application
    @job_application = JobApplication.find(params[:id])
  end

  def job_application_params
    params.require(:job_application).permit(
      :company_name, :job_title, :location, :work_arrangement,
      :salary_range, :job_description, :contact_email,
      :application_instructions, :job_url, :status, :notes,
      :cover_letter, :applied_at, :followed_up_at, skills: []
    )
  end
end
