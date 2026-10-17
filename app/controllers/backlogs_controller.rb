class BacklogsController < ApplicationController
  include ProjectScoped

  def show
    @backlog = Backlog.new(project: @project, filter: params[:filter])
  end
end
