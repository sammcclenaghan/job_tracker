require "test_helper"

class ResumesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @resume = resumes(:main_resume)
  end

  test "should get show" do
    get resume_url
    assert_response :success
  end

  test "should get edit" do
    get edit_resume_url
    assert_response :success
  end

  test "should update resume" do
    patch resume_url, params: {
      resume: { content: "Updated resume content" }
    }
    assert_redirected_to resume_url
    @resume.reload
    assert_equal "Updated resume content", @resume.content
  end

  test "should not update with blank content" do
    patch resume_url, params: {
      resume: { content: "" }
    }
    assert_response :unprocessable_entity
  end

  test "creates resume if none exists" do
    Resume.delete_all
    get resume_url
    assert_response :success
    assert Resume.exists?
  end
end
