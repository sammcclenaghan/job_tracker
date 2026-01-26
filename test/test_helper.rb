ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Disable external HTTP connections (tests should mock all API calls)
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Helper to stub OpenRouter API responses
    def stub_openrouter_success(response_content)
      stub_request(:post, LlmService::OPENROUTER_URL)
        .to_return(
          status: 200,
          body: {
            choices: [{ message: { content: response_content } }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_openrouter_error(message: "API Error", status: 500)
      stub_request(:post, LlmService::OPENROUTER_URL)
        .to_return(
          status: status,
          body: { error: { message: message } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
