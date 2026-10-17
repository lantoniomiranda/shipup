class SearchesController < ApplicationController
  def show
    @search = Search.new(workspace: Current.workspace, query: params[:q], scope: params[:scope])
    # A scoped search can't know the other tabs' counts, so count everything for the tab labels.
    @counts = @search.scope == "everything" ? @search.results.counts : Search.new(workspace: Current.workspace, query: params[:q]).results.counts
    render layout: false
  end
end
