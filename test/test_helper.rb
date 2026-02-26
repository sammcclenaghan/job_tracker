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

    def set_all_providers(provider)
      LlmService::FEATURES.each { |f| Setting.set("provider_#{f}", provider) }
    end

    # Helper to stub OpenRouter API responses
    def stub_openrouter_success(response_content)
      set_all_providers("openrouter")
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
      set_all_providers("openrouter")
      stub_request(:post, LlmService::OPENROUTER_URL)
        .to_return(
          status: status,
          body: { error: { message: message } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_ollama_success(response_content, base_url: LlmService::DEFAULT_OLLAMA_URL)
      set_all_providers("ollama")
      Setting.set("ollama_base_url", base_url)
      Setting.set("ollama_model", "glm4")
      stub_request(:post, "#{base_url}/v1/chat/completions")
        .to_return(
          status: 200,
          body: {
            choices: [{ message: { content: response_content } }]
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    def stub_ollama_error(message: "API Error", status: 500, base_url: LlmService::DEFAULT_OLLAMA_URL)
      set_all_providers("ollama")
      Setting.set("ollama_base_url", base_url)
      Setting.set("ollama_model", "glm4")
      stub_request(:post, "#{base_url}/v1/chat/completions")
        .to_return(
          status: status,
          body: { error: { message: message } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end
  end
end
