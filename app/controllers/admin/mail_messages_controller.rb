# frozen_string_literal: true

class Admin::MailMessagesController < Admin::ApplicationController
  before_action :require_admin!

  AUDIENCES = %w[individual broadcast silent].freeze

  def index
    @pagy, @mail_messages = pagy(MailMessage.order(created_at: :desc).includes(:user))
  end

  def new
    @users = User.kept.order(:display_name)
    @audience = AUDIENCES.include?(params[:audience]) ? params[:audience] : "individual"
    @silent_count = User.silent_signups.count
  end

  def create
    subject = params[:subject].to_s.strip
    body = params[:body].to_s.strip
    audience = AUDIENCES.include?(params[:audience]) ? params[:audience] : "individual"

    if subject.blank?
      redirect_to new_admin_mail_message_path(audience: audience), alert: "Subject is required." and return
    end

    recipients = case audience
    when "broadcast"
      User.kept
    when "silent"
      User.silent_signups
    else
      recipient = User.kept.find_by(id: params[:recipient_id])
      recipient ? [ recipient ] : []
    end

    if recipients.empty?
      redirect_to new_admin_mail_message_path(audience: audience), alert: "Pick a recipient or check audience." and return
    end

    count = 0
    MailMessage.transaction do
      recipients.each do |user|
        MailMessage.create!(user: user, subject: subject, body: body, kind: "admin_message")
        count += 1
      end
    end

    redirect_to admin_mail_messages_path, notice: "Sent to #{count} recipient#{'s' unless count == 1}."
  end
end
