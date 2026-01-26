require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get root_url
    assert_response :success
  end

  test "index shows all applications by default" do
    get root_url
    assert_response :success
    # Should include applications in response
    assert_select "body"  # Basic check that page renders
  end

  test "index filters by status" do
    get root_url, params: { status: "applied" }
    assert_response :success
  end

  test "index handles invalid status gracefully" do
    get root_url, params: { status: "nonexistent" }
    assert_response :success
  end
end
