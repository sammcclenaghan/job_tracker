require "test_helper"

class JobApplicationTest < ActiveSupport::TestCase
  # Validations
  test "valid with company_name and job_title" do
    app = JobApplication.new(company_name: "Test Co", job_title: "Developer")
    assert app.valid?
  end

  test "invalid without company_name" do
    app = JobApplication.new(job_title: "Developer")
    assert_not app.valid?
    assert_includes app.errors[:company_name], "can't be blank"
  end

  test "invalid without job_title" do
    app = JobApplication.new(company_name: "Test Co")
    assert_not app.valid?
    assert_includes app.errors[:job_title], "can't be blank"
  end

  test "invalid with unknown status" do
    app = JobApplication.new(company_name: "Test", job_title: "Dev", status: "unknown")
    assert_not app.valid?
    assert_includes app.errors[:status], "is not included in the list"
  end

  test "valid with all known statuses" do
    JobApplication::STATUSES.each do |status|
      app = JobApplication.new(company_name: "Test", job_title: "Dev", status: status)
      assert app.valid?, "Expected status '#{status}' to be valid"
    end
  end

  test "valid with blank work_arrangement" do
    app = JobApplication.new(company_name: "Test", job_title: "Dev", work_arrangement: "")
    assert app.valid?
  end

  test "invalid with unknown work_arrangement" do
    app = JobApplication.new(company_name: "Test", job_title: "Dev", work_arrangement: "unknown")
    assert_not app.valid?
    assert_includes app.errors[:work_arrangement], "is not included in the list"
  end

  # Default status
  test "sets default status to saved" do
    app = JobApplication.new(company_name: "Test", job_title: "Dev")
    app.valid?
    assert_equal "saved", app.status
  end

  test "does not override existing status" do
    app = JobApplication.new(company_name: "Test", job_title: "Dev", status: "applied")
    app.valid?
    assert_equal "applied", app.status
  end

  # Scopes
  test "by_status scope filters correctly" do
    applied = job_applications(:applied_application)
    saved = job_applications(:saved_application)

    results = JobApplication.by_status("applied")
    assert_includes results, applied
    assert_not_includes results, saved
  end

  test "recent scope orders by created_at desc" do
    # Just verify that the scope applies the correct ordering
    # by checking SQL includes ORDER BY created_at DESC
    sql = JobApplication.recent.to_sql
    assert_match /ORDER BY.*created_at.*DESC/i, sql
  end

  test "applied scope excludes saved applications" do
    saved = job_applications(:saved_application)
    applied = job_applications(:applied_application)

    results = JobApplication.applied
    assert_includes results, applied
    assert_not_includes results, saved
  end

  # Status color methods
  test "status_color returns correct colors" do
    expected = {
      "saved" => "gray",
      "applied" => "blue",
      "interviewing" => "yellow",
      "offer" => "green",
      "rejected" => "red",
      "withdrawn" => "purple"
    }

    expected.each do |status, color|
      app = JobApplication.new(status: status)
      assert_equal color, app.status_color, "Expected #{status} to return #{color}"
    end
  end

  test "status_color returns gray for unknown status" do
    app = JobApplication.new
    app.instance_variable_set(:@attributes, app.instance_variable_get(:@attributes))
    def app.status; "unknown"; end
    assert_equal "gray", app.status_color
  end

  test "status_badge_classes returns correct classes" do
    app = JobApplication.new(status: "applied")
    assert_equal "bg-blue-100 text-blue-700", app.status_badge_classes
  end

  # Skills methods
  test "skills_list returns array when skills is array" do
    app = JobApplication.new(skills: ["Ruby", "Rails"])
    assert_equal ["Ruby", "Rails"], app.skills_list
  end

  test "skills_list returns empty array when skills is nil" do
    app = JobApplication.new(skills: nil)
    assert_equal [], app.skills_list
  end

  test "skills_list returns empty array when skills is not array" do
    app = JobApplication.new
    app.skills = "not an array"
    assert_equal [], app.skills_list
  end

  # Skills analysis methods
  test "has_skills_analysis? returns false when nil" do
    app = JobApplication.new(skills_analysis: nil)
    assert_not app.has_skills_analysis?
  end

  test "has_skills_analysis? returns false when empty hash" do
    app = JobApplication.new(skills_analysis: {})
    assert_not app.has_skills_analysis?
  end

  test "has_skills_analysis? returns true when populated" do
    app = job_applications(:interviewing_application)
    assert app.has_skills_analysis?
  end

  test "matching_skills returns array from skills_analysis" do
    app = job_applications(:interviewing_application)
    assert_kind_of Array, app.matching_skills
    assert app.matching_skills.any?
  end

  test "matching_skills returns empty array without analysis" do
    app = JobApplication.new
    assert_equal [], app.matching_skills
  end

  test "skills_to_highlight returns array from skills_analysis" do
    app = job_applications(:interviewing_application)
    assert_kind_of Array, app.skills_to_highlight
    assert app.skills_to_highlight.any?
  end

  test "skills_to_develop returns array from skills_analysis" do
    app = job_applications(:interviewing_application)
    assert_kind_of Array, app.skills_to_develop
    assert app.skills_to_develop.any?
  end
end
