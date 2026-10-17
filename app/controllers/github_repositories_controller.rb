# Links GitHub repositories to projects so pull requests flow into tasks. Admin only.
class GithubRepositoriesController < ApplicationController
  layout "app"
  before_action :require_workspace_admin
  before_action :require_connection

  def index
    @projects = Current.workspace.projects.ordered.includes(:github_repositories)
    @repositories = available_repositories
  end

  def create
    project = Current.workspace.projects.find_by!(key: params[:project_id].to_s.upcase)
    repo = available_repositories.find { |candidate| candidate[:external_id].to_s == params[:external_id].to_s }
    return redirect_to github_repositories_path, alert: "Pick a repository first." unless repo

    GithubRepository.transaction do
      project.github_repositories.create!(integration_connection: @connection, external_id: repo[:external_id], full_name: repo[:full_name])
      client.create_webhook(repo[:full_name], url: webhooks_github_url, secret: ENV.fetch("GITHUB_WEBHOOK_SECRET", ""))
    end
    redirect_to github_repositories_path, notice: "#{repo[:full_name]} linked to #{project.name}."
  rescue Integrations::Error, ActiveRecord::RecordInvalid => error
    Rails.logger.warn("GitHub link failed: #{error.message}")
    redirect_to github_repositories_path, alert: "Couldn't link that repository. Check your GitHub permissions and try again."
  end

  def destroy
    repository = GithubRepository.joins(:project).where(projects: { workspace_id: Current.workspace.id }).find(params[:id])
    repository.destroy!
    redirect_to github_repositories_path, notice: "#{repository.full_name} unlinked.", status: :see_other
  end

  private

  def require_connection
    @connection = Current.workspace.connection_for("github")
    redirect_to integrations_path, alert: "Connect GitHub first." unless @connection
  end

  def client
    @client ||= Integrations::Github::Client.new(@connection)
  end

  def available_repositories
    @available_repositories ||= client.repositories
  rescue Integrations::Error
    flash.now[:alert] = "Couldn't load your GitHub repositories."
    []
  end
end
