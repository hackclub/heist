ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Bypass session/cookie machinery in tests by reading a thread-local user id from
# Authentication#set_current_user. Production is unaffected: the override only
# fires when a test explicitly calls sign_in_as.
module TestAuthentication
  def set_current_user
    if (uid = Thread.current[:test_signed_in_user_id])
      @current_user = User.find_by(id: uid)
    else
      super
    end
  end
end
ApplicationController.prepend(TestAuthentication)

module SignInHelper
  def sign_in_as(user)
    Thread.current[:test_signed_in_user_id] = user&.id
  end

  def sign_out
    Thread.current[:test_signed_in_user_id] = nil
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SignInHelper

    teardown { sign_out }

    # Add more helper methods to be used by all tests here...
  end
end
