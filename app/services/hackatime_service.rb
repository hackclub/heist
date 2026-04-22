# typed: true
# frozen_string_literal: true

require "faraday"
require "json"

module HackatimeService
  extend T::Sig

  BASE_URL = "https://hackatime.hackclub.com"
  API_PATH = "/api/v1"
  EXCLUDED_PROJECTS = [ "Other", "<<LAST_PROJECT>>" ].freeze

  TRACER = OpenTelemetry.tracer_provider.tracer("hackatime-service")

  module_function

  def host
    ENV.fetch("HACKATIME_URL", BASE_URL)
  end

  def authorize_url(redirect_uri, state)
    params = {
      client_id: ENV.fetch("HACKATIME_CLIENT_ID"),
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: "read_stats read_logged_time",
      state: state
    }
    "#{host}/oauth/authorize?#{params.to_query}"
  end

  sig { params(code: String, redirect_uri: String).returns(T.nilable(T::Hash[String, T.untyped])) }
  def exchange_code_for_token(code, redirect_uri)
    TRACER.in_span("HackatimeService.exchange_code_for_token") do |span|
      response = connection.post("/oauth/token") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = {
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          client_id: ENV.fetch("HACKATIME_CLIENT_ID"),
          client_secret: ENV.fetch("HACKATIME_CLIENT_SECRET")
        }.to_query
      end

      span.set_attribute("hackatime.response_status", response.status)

      unless response.success?
        span.set_attribute("exception.slug", "err-hackatime-token-exchange-failed")
        span.set_attribute("error", true)
        Rails.logger.error("Hackatime token exchange failed: #{response.status} - #{response.body}")
        return nil
      end

      JSON.parse(response.body)
    end
  rescue StandardError => e
    Rails.logger.error("Hackatime token exchange error: #{e.class}: #{e.message}")
    nil
  end

  def fetch_authenticated_user(access_token)
    TRACER.in_span("HackatimeService.fetch_authenticated_user") do |span|
      response = api_connection.get("#{API_PATH}/authenticated/me") do |req|
        req.headers["Authorization"] = "Bearer #{access_token}"
      end

      span.set_attribute("hackatime.response_status", response.status)

      unless response.success?
        span.set_attribute("exception.slug", "err-hackatime-fetch-user-failed")
        span.set_attribute("error", true)
        Rails.logger.warn("Hackatime /authenticated/me failed with status #{response.status}")
        return nil
      end

      JSON.parse(response.body)
    end
  rescue StandardError => e
    Rails.logger.error("Hackatime /authenticated/me error: #{e.class}: #{e.message}")
    nil
  end

  def fetch_stats(hackatime_uid, start_date: nil, end_date: nil)
    TRACER.in_span("HackatimeService.fetch_stats") do |span|
      span.set_attribute("hackatime.uid", hackatime_uid)

      params = {}
      params[:start] = start_date if start_date.present?
      params[:end] = end_date if end_date.present?

      response = api_connection.get("#{API_PATH}/users/#{hackatime_uid}/stats", params) do |req|
        req.headers["Authorization"] = "Bearer #{bypass_token}" if bypass_token.present?
      end

      span.set_attribute("hackatime.response_status", response.status)

      unless response.success?
        span.set_attribute("exception.slug", "err-hackatime-fetch-stats-failed")
        span.set_attribute("error", true)
        Rails.logger.warn("Hackatime stats fetch failed for #{hackatime_uid}: #{response.status}")
        return nil
      end

      JSON.parse(response.body)
    end
  rescue StandardError => e
    Rails.logger.error("Hackatime stats error: #{e.class}: #{e.message}")
    nil
  end

  def fetch_projects(hackatime_uid, start_date: nil, end_date: nil)
    stats = fetch_stats(hackatime_uid, start_date: start_date, end_date: end_date)
    return [] unless stats

    projects = stats.dig("data", "projects") || []
    projects.reject { |p| EXCLUDED_PROJECTS.include?(p["name"]) }
  end

  def fetch_total_seconds(hackatime_uid, project_names: nil, start_date: nil, end_date: nil)
    projects = fetch_projects(hackatime_uid, start_date: start_date, end_date: end_date)
    return 0 if projects.blank?

    if project_names.present?
      projects = projects.select { |p| project_names.include?(p["name"]) }
    end

    projects.sum { |p| p["total_seconds"].to_i }
  end

  def bypass_token
    ENV.fetch("HACKATIME_BYPASS_TOKEN", nil)
  end

  def connection
    @connection ||= Faraday.new(url: host)
  end

  def api_connection
    @api_connection ||= Faraday.new(url: host)
  end
end
