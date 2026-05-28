# frozen_string_literal: true

class Projects::ShipsController < ApplicationController
  before_action :set_project

  def create
    authorize @project, :ship?

    if HackatimeService.fetch_stats(current_user.hackatime_uid).nil?
      redirect_to @project, alert: "Hackatime is unreachable right now. Try again in a moment."
      return
    end

    delta = compute_delta_seconds(@project)

    if delta <= 0
      redirect_to @project, alert: "No new Hackatime hours to ship since your last approval."
      return
    end

    ship = @project.ships.build(
      status: :pending,
      approved_seconds: delta,
      frozen_demo_link: @project.demo_link,
      frozen_repo_link: @project.repo_link,
      justification: ship_params[:justification].presence
    )

    if ship.save
      redirect_to @project, notice: "Submitted for review."
    else
      redirect_to @project, alert: ship.errors.full_messages.to_sentence
    end
  end

  private

  def set_project
    @project = Project.kept.find(params[:project_id])
  end

  def ship_params
    params.fetch(:ship, {}).permit(:justification)
  end

  # Hours since last approved ship on this project. Project-name match is the
  # only join Hackatime gives us; mismatched names return 0 by design.
  def compute_delta_seconds(project)
    total = current_user.hackatime_total_seconds(project_names: [ project.name ])
    prior = project.ships.approved.sum(:approved_seconds).to_i
    total - prior
  end
end
