require "faraday"
require "json"

module FerretService
  module_function

  def search(query, **options)
    params = options.slice(:limit, :min_hours, :exclude_zero_hours, :country, :ysws_name, :ysws_exclude)
    params[:q] = query if query.present?

    response = connection.get("/search.json", params)

    unless response.success?
      Rails.logger.warn("Ferret search failed with status #{response.status}")
      return nil
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Ferret search error: #{e.class}: #{e.message}")
    nil
  end

  def ysws_names
    response = connection.get("/ysws_names.json")

    unless response.success?
      Rails.logger.warn("Ferret ysws_names failed with status #{response.status}")
      return []
    end

    JSON.parse(response.body)
  rescue StandardError => e
    Rails.logger.error("Ferret ysws_names error: #{e.class}: #{e.message}")
    []
  end

  def available?
    response = connection.head("/")
    response.success?
  rescue StandardError
    false
  end

  def connection
    @connection ||= Faraday.new(url: ENV.fetch("FERRET_URL"))
  end
end
