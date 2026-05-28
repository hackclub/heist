# == Schema Information
#
# Table name: ships
#
#  id                :bigint           not null, primary key
#  approved_seconds  :integer
#  claim_expires_at  :datetime
#  feedback          :text
#  frozen_demo_link  :string
#  frozen_hca_data   :text
#  frozen_repo_link  :string
#  frozen_screenshot :string
#  justification     :string
#  status            :integer          default("pending"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  project_id        :bigint           not null
#  reviewer_id       :bigint
#
# Indexes
#
#  index_ships_on_claim_expires_at  (claim_expires_at) WHERE (claim_expires_at IS NOT NULL)
#  index_ships_on_project_id        (project_id)
#  index_ships_on_reviewer_id       (reviewer_id)
#  index_ships_on_status            (status)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (reviewer_id => users.id)
#
require "test_helper"

class ShipTest < ActiveSupport::TestCase
  test "allows pending ship to be approved" do
    ship = ships(:one)
    ship.update_columns(status: Ship.statuses[:pending])
    ship.reload

    assert ship.update(status: :approved)
  end

  test "blocks approved ship from reverting to pending" do
    ship = ships(:one) # fixture is :approved
    ship.reload

    assert_not ship.update(status: :pending)
    assert_includes ship.errors[:status], "cannot transition from approved"
  end

  test "blocks rejected ship from moving to approved" do
    ship = ships(:one)
    ship.update_columns(status: Ship.statuses[:rejected])
    ship.reload

    assert_not ship.update(status: :approved)
    assert_includes ship.errors[:status], "cannot transition from rejected"
  end

  test "blocks returned ship from moving back to pending" do
    ship = ships(:one)
    ship.update_columns(status: Ship.statuses[:returned])
    ship.reload

    assert_not ship.update(status: :pending)
    assert_includes ship.errors[:status], "cannot transition from returned"
  end

  test "permits non-status updates on a terminal ship" do
    ship = ships(:one) # :approved
    ship.reload

    assert ship.update(feedback: "looks good")
  end

  test "atomic_claim! claims an unclaimed ship" do
    ship = ships(:one)
    ship.update_columns(reviewer_id: nil, claim_expires_at: nil)
    reviewer = users(:one)

    assert Ship.atomic_claim!(ship.id, reviewer)
    ship.reload
    assert_equal reviewer.id, ship.reviewer_id
    assert ship.claim_expires_at > Time.current
  end

  test "atomic_claim! is idempotent for the same reviewer" do
    ship = ships(:one)
    reviewer = users(:one)
    Ship.atomic_claim!(ship.id, reviewer)
    first_expiry = ship.reload.claim_expires_at

    travel 1.minute do
      assert Ship.atomic_claim!(ship.id, reviewer)
    end

    assert ship.reload.claim_expires_at > first_expiry
  end

  test "atomic_claim! blocks a different reviewer with an unexpired claim" do
    ship = ships(:one)
    alice = users(:one)
    bob = users(:two)
    Ship.atomic_claim!(ship.id, alice)

    assert_not Ship.atomic_claim!(ship.id, bob)
    assert_equal alice.id, ship.reload.reviewer_id
  end

  test "atomic_claim! takes over an expired claim" do
    ship = ships(:one)
    alice = users(:one)
    bob = users(:two)
    ship.update_columns(reviewer_id: alice.id, claim_expires_at: 1.minute.ago)

    assert Ship.atomic_claim!(ship.id, bob)
    assert_equal bob.id, ship.reload.reviewer_id
  end
end
