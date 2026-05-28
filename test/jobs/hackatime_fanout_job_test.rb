# frozen_string_literal: true

require "test_helper"

class HackatimeFanoutJobTest < ActiveJob::TestCase
  test "enqueues a refresh job for each linked, kept user" do
    User.update_all(hackatime_token: nil, hackatime_uid: nil, discarded_at: nil)
    linked = users(:two)
    linked.update_columns(hackatime_token: "tok", hackatime_uid: "uid")
    discarded = users(:one)
    discarded.update_columns(hackatime_token: "tok", hackatime_uid: "uid")
    discarded.discard

    assert_enqueued_jobs 1, only: HackatimeRefreshJob do
      HackatimeFanoutJob.new.perform
    end

    enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j["job_class"] == "HackatimeRefreshJob" }
    assert_equal linked.id, enqueued["arguments"].first
  end

  test "no users linked enqueues nothing" do
    User.update_all(hackatime_token: nil, hackatime_uid: nil)

    assert_enqueued_jobs 0, only: HackatimeRefreshJob do
      HackatimeFanoutJob.new.perform
    end
  end
end
