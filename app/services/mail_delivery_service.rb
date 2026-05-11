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

  def welcome(user)
    return if MailMessage.where(user: user, kind: "welcome").exists?

    handle = user.display_name.to_s.downcase.presence || "partner"
    body = <<~MAIL.strip
      welcome, #{handle}. you've been added to the manifest.

      the score is 1,000 hours of code, logged collectively across the weekend. your crew is everyone else who signed in. you log time, the leaderboard moves, the take gets closer to open.

      two things to do now:
      > link hackatime so your hours count
      > ship your first project when you have something to show

      the wire goes live when we go live. see you on the floor.
    MAIL

    MailMessage.create!(
      user: user,
      subject: "welcome.heist",
      body: body,
      kind: "welcome"
    )
  end
end
