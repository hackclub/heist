class HackatimeAuthController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :callback, with: -> { redirect_to home_path, alert: "Try again later." }

  def start
    state = SecureRandom.hex(24)
    session[:hackatime_state] = state

    redirect_to HackatimeService.authorize_url(hackatime_callback_url, state), allow_other_host: true
  end

  def callback
    if params[:state] != session[:hackatime_state]
      session[:hackatime_state] = nil
      redirect_to home_path, alert: "Authentication failed due to CSRF token mismatch."
      return
    end

    session[:hackatime_state] = nil

    token_data = HackatimeService.exchange_code_for_token(params[:code], hackatime_callback_url)
    unless token_data&.dig("access_token")
      redirect_to home_path, alert: "Failed to connect Hackatime. Please try again."
      return
    end

    access_token = token_data["access_token"]

    user_data = HackatimeService.fetch_authenticated_user(access_token)
    unless user_data
      redirect_to home_path, alert: "Failed to verify Hackatime identity. Please try again."
      return
    end

    hackatime_uid = user_data.dig("data", "id") || user_data.dig("data", "username")
    unless hackatime_uid
      redirect_to home_path, alert: "Could not determine Hackatime user ID."
      return
    end

    current_user.update!(hackatime_token: access_token, hackatime_uid: hackatime_uid)

    redirect_to home_path, notice: "Hackatime connected successfully!"
  end

  def disconnect
    current_user.update!(hackatime_token: nil, hackatime_uid: nil)
    redirect_to home_path, notice: "Hackatime disconnected."
  end
end
