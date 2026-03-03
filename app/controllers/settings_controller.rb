class SettingsController < ApplicationController
  def edit
    @feature_providers = LlmService::FEATURES.index_with { |f| LlmService.provider_for(f) }
    @feature_models = LlmService::FEATURES.index_with { |f| LlmService.model_for(f) }
    @ollama_base_url = Setting.get("ollama_base_url") || LlmService::DEFAULT_OLLAMA_URL
    @ollama_model = Setting.get("ollama_model") || LlmService::DEFAULT_OLLAMA_MODEL
    @openrouter_api_key_present = Setting.get("openrouter_api_key").present? ||
      Rails.application.credentials.openrouter.api_key.present?
  end

  def update
    LlmService::FEATURES.each do |feature|
      value = params.dig(:providers, feature)
      Setting.set("provider_#{feature}", value) if value.present?

      next unless params[:models]&.key?(feature)

      model_value = params.dig(:models, feature).to_s.strip
      Setting.set("model_#{feature}", model_value.presence)
    end

    Setting.set("openrouter_api_key", params[:openrouter_api_key]) if params[:openrouter_api_key].present?
    Setting.set("ollama_base_url", params[:ollama_base_url].presence || LlmService::DEFAULT_OLLAMA_URL)
    Setting.set("ollama_model", params[:ollama_model].presence || LlmService::DEFAULT_OLLAMA_MODEL)

    redirect_to settings_path, notice: "Settings saved."
  end
end
