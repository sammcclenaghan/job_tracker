class ExperienceProfileService
  STOPWORDS = %w[
    the a an and or but with for from this that these those your you
    role position company team work worked building built develop developed
    engineer engineering software
  ].freeze

  def initialize(entries: ExperienceEntry.recent)
    @entries = entries.to_a
  end

  def present?
    @entries.any?
  end

  def profile_text_for(job_application: nil, limit: 8)
    chosen = if job_application
      relevant_entries_for(job_application, limit: limit)
    else
      @entries.first(limit)
    end

    chosen.map(&:to_profile_block).join("\n\n---\n\n")
  end

  private

  def relevant_entries_for(job_application, limit:)
    terms = query_terms_for(job_application)
    scored = @entries.map do |entry|
      [entry, relevance_score(entry, terms)]
    end

    top = scored
      .sort_by { |(_entry, score)| -score }
      .first(limit)
      .map(&:first)

    if top.size < limit
      top += (@entries - top).first(limit - top.size)
    end

    top
  end

  def query_terms_for(job_application)
    raw = [
      job_application.job_title,
      job_application.company_name,
      job_application.job_description,
      job_application.skills_list.join(" ")
    ].compact.join(" ")

    raw
      .downcase
      .scan(/[a-z0-9+#.\-]+/)
      .reject { |w| w.length < 3 || STOPWORDS.include?(w) }
      .uniq
  end

  def relevance_score(entry, terms)
    text = entry.search_text
    terms.sum do |term|
      text.include?(term) ? 1 : 0
    end
  end
end
