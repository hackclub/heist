# frozen_string_literal: true

module OtelContext
  extend ActiveSupport::Concern

  included do
    before_action :set_otel_context
  end

  private

  def set_otel_context
    span = OpenTelemetry::Trace.current_span
    return unless span.recording?

    if respond_to?(:current_user, true) && current_user.present?
      span.set_attribute("enduser.id", current_user.id)
      span.set_attribute("app.user_email", current_user.email)
    end

    span.set_attribute("app.request_id", request.request_id)
  end
end
