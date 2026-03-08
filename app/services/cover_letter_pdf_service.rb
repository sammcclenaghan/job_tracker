class CoverLetterPdfService
  TEMPLATE_PATH = Rails.root.join("app", "templates", "cover_letter.typ.erb")

  PROFILE_DEFAULTS = {
    name: "Sam McClenaghan",
    phone: "780-221-1327",
    email: "sam@aream.ca",
    linkedin: "linkedin.com/in/sam-mcclenaghan",
    site: "github.com/sammcclenaghan"
  }.freeze

  def initialize(job_application)
    @job_application = job_application
  end

  def generate
    Dir.mktmpdir do |dir|
      typ_path = File.join(dir, "cover_letter.typ")
      pdf_path = File.join(dir, "cover_letter.pdf")

      File.write(typ_path, rendered_typst)

      result = system("typst", "compile", typ_path, pdf_path)
      raise "Typst compilation failed" unless result && File.exist?(pdf_path)

      File.binread(pdf_path)
    end
  end

  def filename
    company = @job_application.company_name.parameterize
    "cover_letter_#{company}.pdf"
  end

  private

  def rendered_typst
    template = File.read(TEMPLATE_PATH)
    erb = ERB.new(template)
    erb.result(binding)
  end

  def name
    Setting.get("profile_name") || PROFILE_DEFAULTS[:name]
  end

  def phone
    Setting.get("profile_phone") || PROFILE_DEFAULTS[:phone]
  end

  def email
    Setting.get("profile_email") || PROFILE_DEFAULTS[:email]
  end

  def linkedin
    Setting.get("profile_linkedin") || PROFILE_DEFAULTS[:linkedin]
  end

  def site
    Setting.get("profile_site") || PROFILE_DEFAULTS[:site]
  end

  def company_name
    @job_application.company_name
  end

  def location
    @job_application.location.presence || ""
  end

  def cover_letter_body
    @job_application.cover_letter || ""
  end

  def esc(text)
    text.to_s
        .gsub("#", "\\#")
        .gsub("@", "\@")
        .gsub("$", "\\$")
        .gsub("<", "\\<")
        .gsub(">", "\\>")
  end
end
