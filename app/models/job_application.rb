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

  def skills_to_highlight
    return [] unless has_skills_analysis?
    skills_analysis["skills_to_highlight"] || []
  end

  def skills_to_develop
    return [] unless has_skills_analysis?
    skills_analysis["skills_to_develop"] || []
  end
  private
  def set_default_status
    self.status ||= "saved"
  end
end
