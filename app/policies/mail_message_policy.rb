# frozen_string_literal: true

class MailMessagePolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    admin? || record.user_id == user&.id
  end

  def update?
    show?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user
      return scope.all if user.admin?
      scope.where(user: user)
    end
  end
end
