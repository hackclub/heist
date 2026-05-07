# frozen_string_literal: true

class Admin::MailMessagesController < Admin::ApplicationController
  before_action :require_admin!

  def index
    @pagy, @mail_messages = pagy(MailMessage.order(created_at: :desc).includes(:user))
  end

  def new
    @users = User.kept.order(:display_name)
  end

  def create
    subject = params[:subject].to_s.strip
    body = params[:body].to_s.strip
    broadcast = params[:broadcast] == "1"

    if subject.blank?
      redirect_to new_admin_mail_message_path, alert: "Subject is required." and return
    end

    recipients = if broadcast
                   User.kept
    else
                   recipient = User.kept.find_by(id: params[:recipient_id])
                   recipient ? [ recipient ] : []
    end

    if recipients.empty?
      redirect_to new_admin_mail_message_path, alert: "Pick a recipient or check broadcast." and return
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
