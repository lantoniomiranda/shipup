class BoardsController < ApplicationController
  include ProjectScoped

  def show
    @board = Board.new(project: @project)
    @running_task_id = Current.user.running_time_entry&.task_id
  end
end
