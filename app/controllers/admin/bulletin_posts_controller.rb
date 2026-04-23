# typed: false
# frozen_string_literal: true

class Admin::BulletinPostsController < Admin::ApplicationController
  before_action :require_admin!
  before_action :set_bulletin_post, only: %i[edit update destroy]

  def index
    @bulletin_posts = policy_scope(BulletinPost).order(posted_at: :desc)
  end

  def new
    @bulletin_post = BulletinPost.new
    authorize @bulletin_post
  end

  def create
    @bulletin_post = BulletinPost.new(bulletin_post_params)
    @bulletin_post.author = current_user
    authorize @bulletin_post

    if @bulletin_post.save
      redirect_to admin_bulletin_posts_path, notice: "Bulletin posted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @bulletin_post
  end

  def update
    authorize @bulletin_post
    if @bulletin_post.update(bulletin_post_params)
      redirect_to admin_bulletin_posts_path, notice: "Bulletin updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @bulletin_post
    @bulletin_post.discard
    redirect_to admin_bulletin_posts_path, notice: "Bulletin removed."
  end

  private

  def set_bulletin_post
    @bulletin_post = BulletinPost.find(params[:id])
  end

  def bulletin_post_params
    params.require(:bulletin_post).permit(:title, :body, :posted_at)
  end
end
