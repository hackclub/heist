# frozen_string_literal: true

class MailMessagesController < ApplicationController
  before_action :set_mail_message, only: %i[show update]

  def index
    @pagy, @mail_messages = pagy(policy_scope(MailMessage).kept.order(created_at: :desc))
    @unread_count = policy_scope(MailMessage).kept.unread.count
  end

  def show
    authorize @mail_message
    @mail_message.mark_read!
  end

  def update
    authorize @mail_message
    @mail_message.mark_read!
    redirect_to mail_messages_path, notice: "Marked as read."
  end

  private

  def set_mail_message
    @mail_message = MailMessage.kept.find(params[:id])
  end
end
