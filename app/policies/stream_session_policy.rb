# frozen_string_literal: true

class StreamSessionPolicy < ApplicationPolicy
  def show?
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.kept
    end
  end
end
