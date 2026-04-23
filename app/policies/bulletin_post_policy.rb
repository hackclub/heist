# typed: true
# frozen_string_literal: true

class BulletinPostPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user&.admin? || false
  end

  def update?
    create?
  end

  def destroy?
    create?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if @user&.admin?
        @scope.all
      elsif @user.present?
        @scope.published
      else
        @scope.none
      end
    end
  end
end
