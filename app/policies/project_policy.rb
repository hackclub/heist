# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def show?
    return false if record.discarded? && !admin?
    admin? || !record.is_unlisted || owner?
  end

  def create?
    return false unless user.present?
    return true if user.has_hackatime?
    !user.projects.kept.exists?
  end

  def update?
    return false if record.discarded? && !admin?
    admin? || owner?
  end

  def destroy?
    return false if record.discarded?
    return false if record.ships.approved.exists?
    admin? || owner?
  end

  def ship?
    return false if record.discarded?
    return false if record.ships.pending.exists?
    return false if record.repo_link.blank?
    return false unless user&.has_hackatime?
    owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.admin?
      return scope.none if user.blank?

      scope.kept.where(user: user)
    end
  end
end
