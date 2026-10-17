class ProjectsController < ApplicationController
  def index
    @projects = Current.workspace.projects.ordered
  end
end
