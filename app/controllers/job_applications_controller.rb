class JobApplicationsController < ApplicationController
  before_action :set_job_application, only: [:show, :edit, :update, :destroy, :update_status, :generate_cover_letter]

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
    service = OpenaiService.new
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
      redirect_to @job_application, notice: "Job application was successfully parsed and created!"
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
      redirect_to @job_application, notice: "Status updated to #{params[:status].capitalize}"
    else
      redirect_to @job_application, alert: "Failed to update status"
    end
  end

  def generate_cover_letter
    resume = Resume.first
    if resume.nil? || resume.content.blank?
      redirect_to @job_application, alert: "Please add your resume first."
      return
    end

    service = OpenaiService.new
    result = service.generate_cover_letter(
      resume: resume.content,
      job_title: @job_application.job_title,
      company_name: @job_application.company_name,
      job_description: @job_application.job_description
    )

    if result[:error]
      redirect_to @job_application, alert: result[:error]
    else
      @job_application.update(cover_letter: result[:cover_letter])
      redirect_to @job_application, notice: "Cover letter generated!"
    end
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
