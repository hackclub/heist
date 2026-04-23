module Api
  module V1
    class PresenceController < ApplicationController
      allow_unauthenticated_access
      skip_before_action :verify_authenticity_token

      HEARTBEAT_TTL = 45.seconds

      def ping
        sid = session.id.to_s
        store = Rails.cache.fetch("presence_store", expires_in: 1.hour) { {} }
        store[sid] = Time.now.to_i
        store.reject! { |_, t| t < HEARTBEAT_TTL.ago.to_i }
        Rails.cache.write("presence_store", store, expires_in: 1.hour)
        render json: { count: [store.size, 1].max }
      end
    end
  end
end
