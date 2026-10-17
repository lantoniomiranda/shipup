class AnalyticsController < ApplicationController
  include ProjectScoped

  def show
    @analytics = Analytics.new(project: @project, range: params[:range])
  end
end
