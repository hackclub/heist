class Admin::ShipsController < Admin::ApplicationController
  before_action :set_ship, only: %i[show edit update]

  def index
    base = Ship.includes(:project, :reviewer, project: :user)
    base = base.where(status: params[:status]) if Ship.statuses.key?(params[:status])
    @pagy, @ships = pagy(base.order(created_at: :desc))

    counts = Ship.group(:status).count
    @status_counts = Ship.statuses.keys.index_with { |k| counts[Ship.statuses[k]].to_i }
    @total_count = @status_counts.values.sum
    @pending_seconds = Ship.pending.sum(:approved_seconds).to_i
    @approved_hours = (Ship.approved.sum(:approved_seconds).to_f / 3600).round(1)
    @approved_last_24h = Ship.approved.where(updated_at: 24.hours.ago..).count
  end

  def show
    authorize @ship
  end

  def edit
    authorize @ship

    unless Ship.atomic_claim!(@ship.id, current_user)
      @ship.reload
      redirect_to admin_ship_path(@ship),
                  alert: "This ship is being reviewed by #{@ship.reviewer&.display_name || 'someone else'}; try again later."
    end
  end

  def update
    authorize @ship

    if @ship.update(ship_params)
      redirect_to admin_ship_path(@ship), notice: "Ship updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_ship
    @ship = Ship.find(params[:id])
  end

  def ship_params
    params.expect(ship: [ :status, :feedback, :justification, :approved_seconds, :reviewer_id ])
  end
end
