class JobApplicationsController < ApplicationController
  before_action :set_job_application, only: [:show, :edit, :update, :destroy, :update_status, :generate_cover_letter, :generate_skills_analysis, :generate_resume_suggestions]

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
      GenerateSkillsAnalysisJob.perform_later(@job_application.id)
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

  def generate_cover_letter
    resume = Resume.first
    if resume.nil? || resume.content.blank?
      redirect_to @job_application, alert: "Please add your resume first."
      return
    end

    service = LlmService.new
    feedback = params[:feedback].presence
    result = service.generate_cover_letter(
      resume: resume.content,
      job_title: @job_application.job_title,
      company_name: @job_application.company_name,
      job_description: @job_application.job_description,
      skills_analysis: @job_application.skills_analysis,
      feedback: feedback,
      previous_cover_letter: feedback ? @job_application.cover_letter : nil
    )

    if result[:error]
      redirect_to @job_application, alert: result[:error]
    else
      @job_application.update(cover_letter: result[:cover_letter], provider_error: nil)
      redirect_to @job_application, notice: "Cover letter generated!"
    end
  end

  def generate_skills_analysis
    resume = Resume.first
    if resume.nil? || resume.content.blank?
      redirect_to @job_application, alert: "Please add your resume first."
      return
    end

    service = LlmService.new
    result = service.generate_skills_analysis(
      resume: resume.content,
      job_title: @job_application.job_title,
      job_description: @job_application.job_description,
      required_skills: @job_application.skills_list
    )

    if result[:error] || result["error"]
      error_msg = result[:error] || result["error"]
      redirect_to @job_application, alert: error_msg
    else
      @job_application.update(skills_analysis: result, provider_error: nil)
      redirect_to @job_application, notice: "Skills analysis generated!"
    end
  end

  def generate_resume_suggestions
    resume = Resume.first
    if resume.nil? || resume.content.blank?
      redirect_to @job_application, alert: "Please add your resume first."
      return
    end

    service = LlmService.new
    result = service.generate_resume_suggestions(
      resume: resume.content,
      job_title: @job_application.job_title,
      job_description: @job_application.job_description,
      required_skills: @job_application.skills_list
    )

    if result[:error] || result["error"]
      error_msg = result[:error] || result["error"]
      redirect_to @job_application, alert: error_msg
    else
      @job_application.update(resume_suggestions: result, provider_error: nil)
      redirect_to @job_application, notice: "Resume suggestions generated!"
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
