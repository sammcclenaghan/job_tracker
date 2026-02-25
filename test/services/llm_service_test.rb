require "test_helper"

class LlmServiceTest < ActiveSupport::TestCase
  setup do
    @service = LlmService.new
  end

  # parse_job_posting tests
  test "parse_job_posting returns parsed data on success" do
    response_json = {
      company_name: "Test Corp",
      job_title: "Ruby Developer",
      location: "Remote",
      work_arrangement: "remote",
      salary_range: "$100k-$150k",
      job_description: "Build great software",
      skills: ["Ruby", "Rails", "PostgreSQL"],
      contact_email: "jobs@test.com",
      application_instructions: "Apply online",
      job_url: "https://test.com/jobs/1"
    }.to_json

    stub_openrouter_success(response_json)

    result = @service.parse_job_posting("Some job posting text")

    assert_equal "Test Corp", result["company_name"]
    assert_equal "Ruby Developer", result["job_title"]
    assert_equal ["Ruby", "Rails", "PostgreSQL"], result["skills"]
  end

  test "parse_job_posting returns error on API failure" do
    stub_openrouter_error(message: "Rate limit exceeded", status: 429)

    result = @service.parse_job_posting("Some job posting text")

    assert result[:error]
    assert_includes result[:error], "Rate limit exceeded"
  end

  test "parse_job_posting returns error on invalid JSON response" do
    stub_openrouter_success("This is not valid JSON {{{")

    result = @service.parse_job_posting("Some job posting text")

    assert result[:error]
    assert_includes result[:error], "Failed to parse response"
  end

  # generate_skills_analysis tests
  test "generate_skills_analysis returns parsed analysis" do
    response_json = {
      matching_skills: [
        { skill: "Ruby", evidence: "5 years experience" }
      ],
      missing_skills: [
        { skill: "Kubernetes", suggestion: "Consider certification" }
      ]
    }.to_json

    stub_openrouter_success(response_json)

    result = @service.generate_skills_analysis(
      resume: "My resume content",
      job_title: "Senior Developer",
      job_description: "Lead development projects",
      required_skills: ["Ruby", "Kubernetes"]
    )

    assert_kind_of Array, result["matching_skills"]
    assert_kind_of Array, result["missing_skills"]
  end

  test "generate_skills_analysis returns error on API failure" do
    stub_openrouter_error(message: "Service unavailable", status: 503)

    result = @service.generate_skills_analysis(
      resume: "Resume",
      job_title: "Dev",
      job_description: "Description",
      required_skills: []
    )

    assert result[:error]
  end

  test "generate_skills_analysis returns error on invalid JSON" do
    stub_openrouter_success("not json")

    result = @service.generate_skills_analysis(
      resume: "Resume",
      job_title: "Dev",
      job_description: "Description",
      required_skills: []
    )

    assert result[:error]
    assert_includes result[:error], "Failed to parse skills analysis"
  end

  # generate_cover_letter tests
  test "generate_cover_letter returns cleaned cover letter" do
    cover_letter_text = "Dear Hiring Manager,\n\nI am **excited** to apply..."

    stub_openrouter_success(cover_letter_text)

    result = @service.generate_cover_letter(
      resume: "My resume",
      job_title: "Developer",
      company_name: "Tech Corp",
      job_description: "Build software"
    )

    assert result[:cover_letter]
    # Bold markdown should be removed
    assert_not_includes result[:cover_letter], "**"
  end

  test "generate_cover_letter includes skills analysis in prompt when provided" do
    stub_openrouter_success("Cover letter content")

    skills_analysis = {
      "matching_skills" => [{ "skill" => "Ruby", "evidence" => "Expert" }],
      "missing_skills" => [{ "skill" => "Go", "suggestion" => "Learn it" }]
    }

    result = @service.generate_cover_letter(
      resume: "My resume",
      job_title: "Developer",
      company_name: "Tech Corp",
      job_description: "Build software",
      skills_analysis: skills_analysis
    )

    assert result[:cover_letter]
  end

  test "generate_cover_letter returns error on API failure" do
    stub_openrouter_error(message: "Timeout", status: 504)

    result = @service.generate_cover_letter(
      resume: "Resume",
      job_title: "Dev",
      company_name: "Corp",
      job_description: "Desc"
    )

    assert result[:error]
  end

  # clean_text tests (via generate_cover_letter)
  test "clean_text handles special characters" do
    # Text with various special characters that should be cleaned
    text_with_specials = "Use em\u2014dash and en\u2013dash and 50 % and ** bold **"

    stub_openrouter_success(text_with_specials)

    result = @service.generate_cover_letter(
      resume: "Resume",
      job_title: "Dev",
      company_name: "Corp",
      job_description: "Desc"
    )

    letter = result[:cover_letter]
    assert_not_includes letter, "\u2014"  # em-dash should be converted
    assert_not_includes letter, "\u2013"  # en-dash should be converted
    assert_not_includes letter, " %"      # space before % should be removed
  end

  # Network error handling
  test "handles Faraday connection errors" do
    stub_request(:post, LlmService::OPENROUTER_URL)
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    result = @service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "API request failed"
  end

  test "handles unexpected errors" do
    stub_request(:post, LlmService::OPENROUTER_URL)
      .to_raise(StandardError.new("Something unexpected"))

    result = @service.parse_job_posting("Some text")

    assert result[:error]
    assert_includes result[:error], "Unexpected error"
  end
end
