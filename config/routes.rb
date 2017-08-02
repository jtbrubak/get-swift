Rails.application.routes.draw do
  resources :assignments, only: [:index]
end
