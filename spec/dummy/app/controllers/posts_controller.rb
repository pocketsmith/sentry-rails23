# frozen_string_literal: true

class PostsController < ApplicationController
  def index
    @posts = Post.all
    render :text => "Found #{@posts.size} posts"
  end

  def show
    @post = Post.find(params[:id])
    render :text => @post.title
  end

  def create
    @post = Post.create!(params[:post])
    render :text => "Created: #{@post.title}"
  end

  def boom
    raise "Intentional error for testing"
  end
end