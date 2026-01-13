class JobApplicationsController < ApplicationController
  def index
    @job_applications = JobApplication.recent
    @job_applications = @job_applications.by_status(params[:status]) if params[:status].present?
  end

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
  def destroy
    @job_application.destroy
    redirect_to job_applications_url, notice: "Job application was successfully deleted."
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
