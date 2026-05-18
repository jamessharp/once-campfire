require "test_helper"

class RoomBotRoutesTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:watercooler)
  end

  test "specific room member routes take precedence over bot room route" do
    assert_recognizes(
      { controller: "rooms/refreshes", action: "show", room_id: @room.to_param },
      "/rooms/#{@room.id}/refresh"
    )

    error = assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path "/rooms/#{@room.id}/settings"
    end
    assert_includes error.message, "Rooms::SettingsController"

    assert_recognizes(
      { controller: "rooms/involvements", action: "show", room_id: @room.to_param },
      "/rooms/#{@room.id}/involvement"
    )

    assert_recognizes(
      { controller: "rooms", action: "show", room_id: @room.to_param, message_id: "123" },
      "/rooms/#{@room.id}/@123"
    )
  end

  test "bot room route only recognizes bot key shaped segments" do
    assert_recognizes(
      { controller: "rooms/by_bots", action: "show", room_id: @room.to_param, bot_key: users(:bender).bot_key },
      "/rooms/#{@room.id}/#{users(:bender).bot_key}"
    )

    assert_raises ActionController::RoutingError do
      Rails.application.routes.recognize_path "/rooms/#{@room.id}/settings-like-bot"
    end
  end
end
