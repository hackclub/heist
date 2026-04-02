# frozen_string_literal: true

return unless ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present?

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

OpenTelemetry::SDK.configure do |c|
  c.service_name = ENV.fetch("OTEL_SERVICE_NAME", "heist")
  c.use_all
end
