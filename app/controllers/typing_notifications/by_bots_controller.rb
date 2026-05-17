class TypingNotifications::ByBotsController < ApplicationController
  include RoomScoped

  allow_bot_access only: %i[ create destroy ]

  skip_before_action :set_room

  def create
    broadcast_typing :start
  end

  def destroy
    broadcast_typing :stop
  end

  private
    def broadcast_typing(action)
      set_room
      TypingNotificationsChannel.broadcast_action_to @room, action: action, user: Current.user
      head :no_content
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
end
