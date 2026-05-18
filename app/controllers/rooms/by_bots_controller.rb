class Rooms::ByBotsController < ApplicationController
  include RoomScoped

  allow_bot_access only: :show

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def show
    render json: {
      room: {
        id: @room.id,
        name: @room.name,
        type: @room.type.demodulize.underscore,
        path: room_path(@room),
        messages_path: room_bot_messages_path(@room, Current.user.bot_key),
        users: @room.users.active.ordered.map { |user| serialize_user(user) }
      }
    }
  end

  private
    def serialize_user(user)
      {
        id: user.id,
        name: user.name,
        bot: user.bot?
      }
    end

    def render_not_found
      head :not_found
    end
end
