class TimelinesController < ApplicationController
  include ProjectScoped

  def show
    @timeline = Timeline.new(project: @project, from: parse_date(params[:from]))
    respond_to do |format|
      format.html
      format.ics { send_data CalendarExport.new(@project, Current.user).to_ics, type: "text/calendar", filename: "#{@project.key.downcase}-calendar.ics" }
    end
  end

  private

  def parse_date(value)
    date = Date.iso8601(value.to_s)
    date if (Date.current - 10.years..Date.current + 10.years).cover?(date)
  rescue ArgumentError
    nil
  end
end
