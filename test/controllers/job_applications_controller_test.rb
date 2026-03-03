require "test_helper"

class JobApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @job_application = job_applications(:saved_application)
    @applied_application = job_applications(:applied_application)
  end

  # show
  test "should get show" do
    get job_application_url(@job_application)
    assert_response :success
  end

  # new
  test "should get new" do
    get new_job_application_url
    assert_response :success
  end

  # new_from_paste
  test "should get new_from_paste" do
    get new_from_paste_job_applications_url
    assert_response :success
  end

  # create
  test "should create job_application and enqueue insights" do
    assert_difference("JobApplication.count") do
      post job_applications_url, params: {
        job_application: {
          company_name: "New Company",
          job_title: "New Position"
        }
      }
    end
    assert_redirected_to job_application_url(JobApplication.last)
  end

  test "should not create job_application with invalid params" do
    assert_no_difference("JobApplication.count") do
      post job_applications_url, params: {
        job_application: {
          company_name: "",
          job_title: ""
        }
      }
    end
    assert_response :unprocessable_entity
  end

  # create_from_paste
  test "create_from_paste fails with blank content" do
    post create_from_paste_job_applications_url, params: { raw_content: "" }
    assert_response :unprocessable_entity
  end

  test "create_from_paste succeeds with valid LLM response" do
    parsed_response = {
      "company_name" => "Parsed Corp",
      "job_title" => "Parsed Developer",
      "location" => "Remote",
      "work_arrangement" => "remote",
      "salary_range" => "$100k",
      "job_description" => "Build stuff",
      "skills" => ["Ruby"],
      "contact_email" => "test@test.com",
      "application_instructions" => "Apply now",
      "job_url" => "https://example.com"
    }.to_json

    stub_openrouter_success(parsed_response)

    assert_difference("JobApplication.count") do
      post create_from_paste_job_applications_url, params: {
        raw_content: "Some job posting content"
      }
    end

    assert_redirected_to job_application_url(JobApplication.last)
    assert_equal "Parsed Corp", JobApplication.last.company_name
  end

  test "create_from_paste handles LLM error" do
    stub_openrouter_error(message: "API Error")

    assert_no_difference("JobApplication.count") do
      post create_from_paste_job_applications_url, params: {
        raw_content: "Some job posting"
      }
    end
    assert_response :unprocessable_entity
  end

  # edit
  test "should get edit" do
    get edit_job_application_url(@job_application)
    assert_response :success
  end

  # update
  test "should update job_application" do
    patch job_application_url(@job_application), params: {
      job_application: { company_name: "Updated Company" }
    }
    assert_redirected_to job_application_url(@job_application)
    @job_application.reload
    assert_equal "Updated Company", @job_application.company_name
  end

  test "should not update with invalid params" do
    patch job_application_url(@job_application), params: {
      job_application: { company_name: "" }
    }
    assert_response :unprocessable_entity
  end

  # update_status
  test "update_status changes status" do
    patch update_status_job_application_url(@job_application), params: { status: "applied" }
    assert_redirected_to job_application_url(@job_application)
    @job_application.reload
    assert_equal "applied", @job_application.status
  end

  test "update_status sets applied_at when changing to applied" do
    assert_nil @job_application.applied_at
    patch update_status_job_application_url(@job_application), params: { status: "applied" }
    @job_application.reload
    assert_not_nil @job_application.applied_at
  end

  test "update_status does not override existing applied_at" do
    original_applied_at = @applied_application.applied_at
    patch update_status_job_application_url(@applied_application), params: { status: "applied" }
    @applied_application.reload
    assert_equal original_applied_at.to_i, @applied_application.applied_at.to_i
  end

  test "update_status responds to json" do
    patch update_status_job_application_url(@job_application, format: :json), params: { status: "applied" }
    assert_response :ok
  end

  # regenerate_cover_letter
  test "regenerate_cover_letter requires experience log" do
    ExperienceEntry.delete_all
    post regenerate_cover_letter_job_application_url(@job_application)
    assert_redirected_to job_application_url(@job_application)
    assert_match /experience log/i, flash[:alert]
  end

  test "regenerate_cover_letter enqueues job" do
    post regenerate_cover_letter_job_application_url(@job_application)
    assert_redirected_to job_application_url(@job_application)
    assert_match /regenerating/i, flash[:notice]
  end

  # regenerate_insights
  test "regenerate_insights enqueues all insight jobs" do
    post regenerate_insights_job_application_url(@job_application)
    assert_redirected_to job_application_url(@job_application)
    assert_match /regenerating/i, flash[:notice]
  end

  # destroy
  test "should destroy job_application" do
    assert_difference("JobApplication.count", -1) do
      delete job_application_url(@job_application)
    end
    assert_redirected_to root_url
  end
end
