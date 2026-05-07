# frozen_string_literal: true

module MailDeliveryService
  module_function

  def ship_status_changed(ship)
    subject, body = case ship.status
    when "approved"
      hours = (ship.approved_seconds.to_i / 3600.0).round(1)
      [ "Your ship was approved", "Nice work. #{hours} hours have been counted toward the program." ]
    when "returned"
      [ "Your ship was returned for revisions", ship.feedback.presence || "Your reviewer left no notes." ]
    when "rejected"
      [ "Your ship was not accepted", ship.feedback.presence || "Your reviewer left no notes." ]
    else
      return nil
    end

    MailMessage.create!(
      user: ship.user,
      subject: subject,
      body: body,
      kind: "ship_status_changed",
      mailable: ship
    )
  end
end
