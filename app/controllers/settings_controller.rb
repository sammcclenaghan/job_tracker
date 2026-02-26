class SettingsController < ApplicationController
  def edit
    @feature_providers = LlmService::FEATURES.index_with { |f| LlmService.provider_for(f) }
    @ollama_base_url = Setting.get("ollama_base_url") || LlmService::DEFAULT_OLLAMA_URL
    @ollama_model = Setting.get("ollama_model") || "glm4"
  end

  def update
    LlmService::FEATURES.each do |feature|
      value = params.dig(:providers, feature)
      Setting.set("provider_#{feature}", value) if value.present?
    end

    Setting.set("ollama_base_url", params[:ollama_base_url].presence || LlmService::DEFAULT_OLLAMA_URL)
    Setting.set("ollama_model", params[:ollama_model].presence || "glm4")

    redirect_to settings_path, notice: "Settings saved."
  end
end
