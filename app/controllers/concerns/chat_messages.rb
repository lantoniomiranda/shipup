# create / update / destroy for a chat thread. Including controllers provide:
#   chat_thread  - the Topic or Task the messages belong to (loaded in a before_action)
#   chat_path(anchor:) - where to go back to
module ChatMessages
  extend ActiveSupport::Concern

  included do
    include ProjectScoped
    before_action :set_chat_thread
    before_action :set_message, only: %i[update destroy]
  end

  def create
    message = chat_messages.build(author: Current.user, body: message_params[:body], parent: chat_messages.find_by(id: message_params[:parent_id]))

    if message.save
      redirect_to chat_path(anchor: "message-#{message.id}"), status: :see_other
    else
      redirect_to chat_path, alert: "Write something before sending.", status: :see_other
    end
  end

  def update
    return render_error(403) unless @message.editable_by?(Current.user)

    if @message.edit!(message_params[:body])
      redirect_to chat_path(anchor: "message-#{@message.id}"), status: :see_other
    end
  rescue ActiveRecord::RecordInvalid
    redirect_to chat_path(anchor: "message-#{@message.id}"), alert: "A message can't be empty. Remove it instead.", status: :see_other
  end

  def destroy
    return render_error(403) unless @message.removable_by?(Current.user, @project)

    @message.remove!
    redirect_to chat_path(anchor: "message-#{@message.id}"), notice: "Message removed.", status: :see_other
  end

  private

  def message_params
    params.expect(message: %i[body parent_id])
  end

  def set_message
    @message = chat_messages.find(params[:id])
  end

  def chat_messages
    chat_thread.messages
  end
end
