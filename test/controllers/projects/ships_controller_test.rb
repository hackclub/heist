# frozen_string_literal: true

require "test_helper"

class Projects::ShipsControllerTest < ActionDispatch::IntegrationTest
  def owner
    users(:two)
  end

  def project
    @project ||= projects(:two).tap do |p|
      p.ships.destroy_all
      p.update_columns(repo_link: "https://github.com/heist/example", name: "demo-project")
      p.user.update_columns(hackatime_token: "tok", hackatime_uid: "uid")
    end
  end

  def with_hackatime_total(seconds, stats: { "data" => { "projects" => [] } })
    original_total = HackatimeService.method(:fetch_total_seconds)
    original_stats = HackatimeService.method(:fetch_stats)
    HackatimeService.define_singleton_method(:fetch_total_seconds) { |*_, **_| seconds }
    HackatimeService.define_singleton_method(:fetch_stats) { |*_, **_| stats }
    yield
  ensure
    HackatimeService.define_singleton_method(:fetch_total_seconds, original_total)
    HackatimeService.define_singleton_method(:fetch_stats, original_stats)
  end

  test "unauthenticated user is redirected" do
    post project_ships_path(projects(:two))
    assert_redirected_to root_path
  end

  test "happy path creates a pending ship with the computed delta" do
    sign_in_as(owner)
    target = project

    with_hackatime_total(3600) do
      assert_difference("Ship.count", 1) do
        post project_ships_path(target), params: { ship: { justification: "Built the thing" } }
      end
    end

    ship = target.ships.order(:created_at).last
    assert_equal "pending", ship.status
    assert_equal 3600, ship.approved_seconds
    assert_equal "https://github.com/heist/example", ship.frozen_repo_link
    assert_equal "Built the thing", ship.justification
    assert_redirected_to project_path(target)
  end

  test "delta subtracts prior approved ship seconds" do
    sign_in_as(owner)
    target = project
    target.ships.create!(status: :approved, approved_seconds: 1200)

    with_hackatime_total(3600) do
      assert_difference("Ship.count", 1) do
        post project_ships_path(target)
      end
    end

    new_ship = target.ships.where(status: :pending).order(:created_at).last
    assert_equal 2400, new_ship.approved_seconds
  end

  test "surfaces a distinct error when Hackatime is unreachable" do
    sign_in_as(owner)
    target = project

    with_hackatime_total(0, stats: nil) do
      assert_no_difference("Ship.count") do
        post project_ships_path(target)
      end
    end

    assert_redirected_to project_path(target)
    assert_match(/hackatime is unreachable/i, flash[:alert])
  end

  test "blocks when delta is zero or negative" do
    sign_in_as(owner)
    target = project
    target.ships.create!(status: :approved, approved_seconds: 5000)

    with_hackatime_total(5000) do
      assert_no_difference("Ship.count") do
        post project_ships_path(target)
      end
    end

    assert_redirected_to project_path(target)
    assert_match(/no new hackatime hours/i, flash[:alert])
  end

  test "blocks when project has no repo_link" do
    sign_in_as(owner)
    target = project
    target.update_columns(repo_link: nil)

    assert_no_difference("Ship.count") do
      post project_ships_path(target)
    end

    assert_match(/not authorized/i, flash[:alert])
  end

  test "blocks when a pending ship already exists" do
    sign_in_as(owner)
    target = project
    target.ships.create!(status: :pending, approved_seconds: 0)

    assert_no_difference("Ship.count") do
      post project_ships_path(target)
    end

    assert_match(/not authorized/i, flash[:alert])
  end

  test "blocks when user has no Hackatime linked" do
    sign_in_as(owner)
    target = project
    owner.update_columns(hackatime_token: nil, hackatime_uid: nil)

    assert_no_difference("Ship.count") do
      post project_ships_path(target)
    end

    assert_match(/not authorized/i, flash[:alert])
  end

  test "blocks non-owner" do
    intruder = users(:one)
    intruder.update_columns(hackatime_token: "tok", hackatime_uid: "uid", roles: [ "user" ])
    sign_in_as(intruder)
    target = project

    assert_no_difference("Ship.count") do
      post project_ships_path(target)
    end

    assert_match(/not authorized/i, flash[:alert])
  end

  test "blocks when project is discarded" do
    sign_in_as(owner)
    target = project
    target.discard

    assert_no_difference("Ship.count") do
      post project_ships_path(target)
    end

    # Project.kept.find raises RecordNotFound -> 404, before authz runs.
    assert_response :not_found
  end
end
