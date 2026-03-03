require "test_helper"

class ResumesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get resume_url
    assert_response :success
  end

  test "should get edit" do
    get edit_resume_url
    assert_response :success
  end

  test "update redirects to edit with alert" do
    patch resume_url
    assert_redirected_to edit_resume_url
    assert_match(/experience log/i, flash[:alert])
  end
end
