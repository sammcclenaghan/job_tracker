require "test_helper"

class ProviderRoutingJobsTest < ActiveJob::TestCase
  test "project recommendations job uses project_recommendations feature" do
    job_application = job_applications(:saved_application)
    captured_feature = nil

    fake_service = Object.new
    fake_service.define_singleton_method(:chat_json) do |feature:, **|
      captured_feature = feature
      { "highlight" => [], "deprioritize" => [], "missing" => [] }
    end

    with_stubbed_llm_service(fake_service) do
      GenerateProjectRecommendationsJob.perform_now(job_application.id)
    end

    assert_equal :project_recommendations, captured_feature
  end

  test "experience tailoring job uses experience_tailoring feature" do
    job_application = job_applications(:saved_application)
    captured_feature = nil

    fake_service = Object.new
    fake_service.define_singleton_method(:chat_json) do |feature:, **|
      captured_feature = feature
      { "jobs" => [] }
    end

    with_stubbed_llm_service(fake_service) do
      GenerateExperienceTailoringJob.perform_now(job_application.id)
    end

    assert_equal :experience_tailoring, captured_feature
  end

  private

  def with_stubbed_llm_service(fake_service)
    original_new = LlmService.method(:new)
    LlmService.define_singleton_method(:new) { fake_service }
    yield
  ensure
    LlmService.define_singleton_method(:new) { |*args, **kwargs, &block| original_new.call(*args, **kwargs, &block) }
  end
end
