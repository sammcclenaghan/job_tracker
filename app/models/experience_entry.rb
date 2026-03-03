class ExperienceEntry < ApplicationRecord
  ENTRY_TYPES = %w[experience project].freeze

  validates :entry_type, inclusion: { in: ENTRY_TYPES }
  validates :title, presence: true
  validates :details, presence: true

  scope :recent, -> { order(updated_at: :desc) }

  def search_text
    [
      entry_type,
      title,
      organization,
      location,
      date_range,
      technologies,
      tags,
      details
    ].compact.join(" ").downcase
  end

  def to_profile_block
    lines = []
    lines << "[#{entry_type.upcase}] #{title}"
    lines << "Organization: #{organization}" if organization.present?
    lines << "Location: #{location}" if location.present?
    lines << "Date Range: #{date_range}" if date_range.present?
    lines << "Technologies: #{technologies}" if technologies.present?
    lines << "Tags: #{tags}" if tags.present?
    lines << "Evidence:\n#{details}"
    lines.join("\n")
  end
end
