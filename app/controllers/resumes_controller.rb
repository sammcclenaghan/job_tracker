class ResumesController < ApplicationController
  def show
    @resume = Resume.current
  end
  def edit
    @resume = Resume.current
  end
  def update
    @resume = Resume.current
    if @resume.update(resume_params)
      redirect_to resume_path, notice: "Resume updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end
  private
  def resume_params
    params.require(:resume).permit(:content)
  end
end
