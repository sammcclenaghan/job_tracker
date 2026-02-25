class JobApplication < ApplicationRecord
  STATUSES=%w[saved applied interviewing offer rejected withdrawn].freeze
  WORK_ARRANGEMENTS=%w[remote hybrid onsite].freeze

  validates :company_name, presence: true
  validates :job_title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :work_arrangement, inclusion: { in: WORK_ARRANGEMENTS }, allow_blank: true

  before_validation :set_default_status

  serialize :skills, coder: JSON
  serialize :skills_analysis, coder: JSON

  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }
  scope :applied, -> { where.not(status: "saved") }

  def status_color
    case status
    when "saved" then "gray"
    when "applied" then "blue"
    when "interviewing" then "yellow"
    when "offer" then "green"
    when "rejected" then "red"
    when "withdrawn" then "purple"
    else "gray"
    end
  end

  def status_badge_classes
    colors = {
      "saved" => "bg-gray-100 text-gray-700",
      "applied" => "bg-blue-100 text-blue-700",
      "interviewing" => "bg-yellow-100 text-yellow-700",
      "offer" => "bg-green-100 text-green-700",
      "rejected" => "bg-red-100 text-red-700",
      "withdrawn" => "bg-purple-100 text-purple-700"
    }
    colors[status] || "bg-gray-100 text-gray-700"
  end
  def skills_list
    skills.is_a?(Array) ? skills : []
  end

  def has_skills_analysis?
    skills_analysis.is_a?(Hash) && skills_analysis.any?
  end

  def matching_skills
    return [] unless has_skills_analysis?
    skills_analysis["matching_skills"] || []
  end

  def missing_skills
    return [] unless has_skills_analysis?
    skills_analysis["missing_skills"] || []
  end

  def skill_status(skill_name)
    return nil unless has_skills_analysis?
    downcased = skill_name.downcase
    return :matching if matching_skills.any? { |s| s["skill"].downcase == downcased }
    return :missing if missing_skills.any? { |s| s["skill"].downcase == downcased }
    nil
  end

  def has_resume_suggestions?
    resume_suggestions.is_a?(Hash) && resume_suggestions.any?
  end

  def suggested_rewrites
    return [] unless has_resume_suggestions?
    resume_suggestions["rewrites"] || []
  end

  def suggested_additions
    return [] unless has_resume_suggestions?
    resume_suggestions["additions"] || []
  end
  private
  def set_default_status
    self.status ||= "saved"
  end
end
