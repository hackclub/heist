class Admin::UsersController < Admin::ApplicationController
  before_action :require_admin!
  before_action :set_user, only: %i[show edit update]

  def index
    scope = User.all
    scope = scope.search(params[:query]) if params[:query].present?
    @pagy, @users = pagy(scope.order(created_at: :desc))
  end

  def show
    @projects = @user.projects.order(created_at: :desc)
  end

  def edit
    authorize @user, :manage_roles?
  end

  def update
    authorize @user, :manage_roles?

    new_roles = Array(params.dig(:user, :roles)).map(&:to_s) & User::ROLES

    if @user == current_user && !new_roles.include?("admin")
      redirect_to edit_admin_user_path(@user), alert: "You cannot remove your own admin role."
      return
    end

    if @user.update(roles: new_roles)
      redirect_to admin_user_path(@user), notice: "Roles updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
