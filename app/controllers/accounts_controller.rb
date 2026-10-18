# Settings → Account: the signed-in user's name, avatar and how they sign in.
class AccountsController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
    @roles = role_summary(@user)
  end

  def update
    @user = Current.user
    if @user.update(params.expect(user: %i[name avatar_icon avatar_color]))
      redirect_to account_path, notice: t("account.saved"), status: :see_other
    else
      @roles = role_summary(@user)
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_content
    end
  end

  private

  # "Manager · Apollo gateway, mobile atlas"
  def role_summary(user)
    managed = user.project_memberships.admin.includes(:project).map { |membership| membership.project.name.downcase }
    role = user.superadmin? ? t("roles.superadmin") : (managed.any? ? t("roles.admin") : t("roles.member"))
    managed.any? ? "#{role} · #{managed.to_sentence(two_words_connector: ", ", last_word_connector: ", ")}" : role
  end
end
