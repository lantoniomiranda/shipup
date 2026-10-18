# Remembers how this person ordered the tabs of the project header (drag and drop).
class ProjectTabOrdersController < ApplicationController
  def update
    Current.user.preference.reorder_project_tabs!(Array(params[:order]))
    head :no_content
  end

  def destroy
    Current.user.preference.update!(project_tab_order: [])
    redirect_back_or_to appearance_path, status: :see_other
  end
end
