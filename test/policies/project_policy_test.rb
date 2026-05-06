# frozen_string_literal: true

require "test_helper"

class ProjectPolicyTest < ActiveSupport::TestCase
  def admin
    users(:one)
  end

  def regular
    users(:two)
  end

  test "owner can destroy a project with no approved ships" do
    project = projects(:two) # belongs to regular
    project.ships.destroy_all

    assert ProjectPolicy.new(regular, project).destroy?
  end

  test "owner cannot destroy a project that has an approved ship" do
    project = projects(:two)
    assert project.ships.approved.exists?, "fixture should have an approved ship"

    assert_not ProjectPolicy.new(regular, project).destroy?
  end

  test "admin cannot destroy a project that has an approved ship" do
    project = projects(:two)
    assert project.ships.approved.exists?, "fixture should have an approved ship"

    assert_not ProjectPolicy.new(admin, project).destroy?
  end

  test "non-owner regular user cannot destroy" do
    project = projects(:one) # belongs to admin
    project.ships.destroy_all

    assert_not ProjectPolicy.new(regular, project).destroy?
  end

  test "destroy refuses on already-discarded projects" do
    project = projects(:two)
    project.ships.destroy_all
    project.discard

    assert_not ProjectPolicy.new(regular, project).destroy?
  end

  test "ship? allows owner with hackatime, repo, no pending ship, kept project" do
    project = projects(:two)
    project.ships.destroy_all
    project.update_columns(repo_link: "https://github.com/heist/example")
    regular.update_columns(hackatime_token: "tok", hackatime_uid: "uid")

    assert ProjectPolicy.new(regular, project).ship?
  end

  test "ship? refuses non-owner" do
    project = projects(:two)
    project.ships.destroy_all
    project.update_columns(repo_link: "https://example.com")
    admin.update_columns(hackatime_token: "tok", hackatime_uid: "uid")

    assert_not ProjectPolicy.new(admin, project).ship?
  end

  test "ship? refuses when a pending ship already exists" do
    project = projects(:two)
    project.ships.destroy_all
    project.ships.create!(status: :pending, approved_seconds: 0)
    project.update_columns(repo_link: "https://example.com")
    regular.update_columns(hackatime_token: "tok", hackatime_uid: "uid")

    assert_not ProjectPolicy.new(regular, project).ship?
  end

  test "ship? refuses when project has no repo_link" do
    project = projects(:two)
    project.ships.destroy_all
    project.update_columns(repo_link: nil)
    regular.update_columns(hackatime_token: "tok", hackatime_uid: "uid")

    assert_not ProjectPolicy.new(regular, project).ship?
  end

  test "ship? refuses when user has no Hackatime linked" do
    project = projects(:two)
    project.ships.destroy_all
    project.update_columns(repo_link: "https://example.com")
    regular.update_columns(hackatime_token: nil, hackatime_uid: nil)

    assert_not ProjectPolicy.new(regular, project).ship?
  end

  test "ship? refuses when project is discarded" do
    project = projects(:two)
    project.ships.destroy_all
    project.update_columns(repo_link: "https://example.com")
    regular.update_columns(hackatime_token: "tok", hackatime_uid: "uid")
    project.discard

    assert_not ProjectPolicy.new(regular, project).ship?
  end
end
