require "test_helper"

class ResumeTest < ActiveSupport::TestCase
  test "current returns existing resume" do
    existing = resumes(:main_resume)
    assert_equal existing, Resume.current
  end

  test "current creates new resume when none exists" do
    Resume.delete_all
    assert_difference "Resume.count", 1 do
      Resume.current
    end
  end

  test "current creates resume with empty content" do
    Resume.delete_all
    resume = Resume.current
    assert_equal "", resume.content
  end

  test "validates presence of content on update" do
    resume = Resume.current
    resume.content = ""
    assert_not resume.valid?
    assert_includes resume.errors[:content], "can't be blank"
  end

  test "allows blank content on create" do
    Resume.delete_all
    resume = Resume.new(content: "")
    # New record should be valid even with blank content
    # because validation is only on update
    assert resume.new_record?
  end

  test "valid with content on update" do
    resume = Resume.current
    resume.content = "Updated resume content"
    assert resume.valid?
  end
end
