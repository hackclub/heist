# typed: true
# frozen_string_literal: true

class RsvpsController < ApplicationController
  allow_unauthenticated_access only: %i[create]

  def create
    authorize Rsvp
    rsvp = Rsvp.find_or_initialize_by(email: params[:email].to_s.strip.downcase)
    rsvp.source ||= "landing"

    if rsvp.persisted? || rsvp.save
      redirect_to root_path(rsvp: "ok"), allow_other_host: false
    else
      redirect_to root_path(rsvp: "error", message: rsvp.errors.full_messages.first), allow_other_host: false
    end
  end
end
