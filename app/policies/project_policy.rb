# frozen_string_literal: true

class ProjectPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    return false if record.discarded? && !admin?
    admin? || !record.is_unlisted || owner?
  end

  def create?
    user.present?
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
      if user&.admin?
        scope.all
      else
        scope.kept.listed.or(scope.kept.where(user: user))
      end
    end
  end
end
