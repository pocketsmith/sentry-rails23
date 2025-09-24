# frozen_string_literal: true

class ApplicationController < ActionController::Base
  protect_from_forgery

  def current_user
    @current_user ||= User.first || User.create!(
      :username => 'test_user',
      :email => 'test@example.com'
    )
  end
end