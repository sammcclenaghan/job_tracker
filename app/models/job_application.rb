class JobApplication < ApplicationRecord
  STATUSES = %w[saved applied interviewing offer rejected withdrawn].freeze
  WORK_ARRANGEMENTS = %w[remote hybrid onsite].freeze
  INSIGHTS_STATUSES = %w[pending processing complete].freeze

  AUTO_INSIGHT_FIELDS = %w[
    match_score project_recommendations experience_tailoring
  ].freeze

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
      "saved" => "bg-gray-100 text-gray-600 border border-gray-200",
      "applied" => "bg-blue-50 text-blue-700 border border-blue-200",
      "interviewing" => "bg-amber-50 text-amber-700 border border-amber-200",
      "offer" => "bg-emerald-50 text-emerald-700 border border-emerald-200",
      "rejected" => "bg-red-50 text-red-700 border border-red-200",
      "withdrawn" => "bg-purple-50 text-purple-700 border border-purple-200"
    }
    colors[status] || "bg-gray-100 text-gray-600 border border-gray-200"
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
    false
  end

  def suggested_rewrites
    []
  end

  def suggested_additions
    []
  end

  def has_project_recommendations?
    project_recommendations.is_a?(Hash) && project_recommendations.any?
  end

  def highlighted_projects
    return [] unless has_project_recommendations?
    project_recommendations["highlight"] || []
  end

  def deprioritized_projects
    return [] unless has_project_recommendations?
    project_recommendations["deprioritize"] || []
  end

  def missing_projects
    return [] unless has_project_recommendations?
    project_recommendations["missing"] || []
  end

  def has_experience_tailoring?
    experience_tailoring.is_a?(Hash) && experience_tailoring.any?
  end

  def tailored_jobs
    return [] unless has_experience_tailoring?
    experience_tailoring["jobs"] || []
  end

  def insights_processing?
    return false unless insights_status == "processing"
    progress = insights_progress
    progress[:completed] < progress[:total]
  end

  def insights_complete?
    return true if insights_status == "complete"
    progress = insights_progress
    progress[:completed] >= progress[:total]
  end

  def check_insights_complete!
    return unless insights_status == "processing"

    all_done = AUTO_INSIGHT_FIELDS.all? { |field| send(field).present? }

    update(insights_status: "complete") if all_done
  end

  def clear_provider_errors!
    update(provider_error: nil)
  end

  def record_provider_error!(feature:, message:)
    feature_name = feature.to_s.humanize
    formatted = "[#{feature_name}] #{message}"

    with_lock do
      lines = provider_error.to_s.lines.map(&:strip).reject(&:blank?)
      lines << formatted
      update(provider_error: lines.uniq.join("\n"))
    end
  end

  def insights_progress
    completed = AUTO_INSIGHT_FIELDS.count { |f| send(f).present? }
    { completed: completed, total: AUTO_INSIGHT_FIELDS.size }
  end

  private

  def set_default_status
    self.status ||= "saved"
  end
end
