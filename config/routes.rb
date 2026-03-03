Rails.application.routes.draw do
  root "dashboard#index"

  resources :job_applications, except: [:index] do
    member do
      post :regenerate_cover_letter
      post :regenerate_insights
      patch :update_status
    end
    collection do
      get :new_from_paste
      post :create_from_paste
    end
  end

  resource :resume, only: [ :show, :edit, :update ]
  resources :experience_entries, only: [ :create, :update, :destroy ]
  resource :settings, only: [ :edit, :update ]

  get "up" => "rails/health#show", as: :rails_health_check
end
