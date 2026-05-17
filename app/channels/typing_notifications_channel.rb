class TypingNotificationsChannel < RoomChannel
  def self.broadcast_action_to(room, action:, user:)
    broadcast_to room, action: action, user: user.slice(:id, :name)
  end

  def start(data)
    self.class.broadcast_action_to @room, action: :start, user: current_user
  end

  def stop(data)
    self.class.broadcast_action_to @room, action: :stop, user: current_user
  end
end
