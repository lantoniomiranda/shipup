class SearchesController < ApplicationController
  def show
    project = Project.visible_to(Current.user).find_by(key: params[:project]) if params[:project].present?
    @search = Search.new(user: Current.user, query: params[:q], scope: params[:scope], project: project)
    # A scoped search can't know the other tabs' counts, so count everything for the tab labels.
    @counts = @search.scope == "everything" ? @search.results.counts : Search.new(user: Current.user, query: params[:q], project: project).results.counts
    render layout: false
  end
end
