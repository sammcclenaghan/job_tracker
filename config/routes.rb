Rails.application.routes.draw do
  root "dashboard#index"

  resources :job_applications, except: [:index] do
    member do
      post :parse
      post :generate_cover_letter
      post :generate_skills_analysis
      post :generate_resume_suggestions
      patch :update_status
    end
    collection do
      get :new_from_paste
      post :create_from_paste
    end
  end

  resource :resume, only: [ :show, :edit, :update ]
  resource :settings, only: [ :edit, :update ]

  get "up" => "rails/health#show", as: :rails_health_check
end
