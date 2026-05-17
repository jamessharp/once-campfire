require "test_helper"

class TypingNotifications::ByBotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:watercooler)
    @bot = users(:bender)
  end

  test "valid bot key starts typing" do
    post room_bot_typing_url(@room, @bot.bot_key)

    assert_response :no_content
    assert_typing_broadcast action: "start"
  end

  test "valid bot key stops typing" do
    delete room_bot_typing_url(@room, @bot.bot_key)

    assert_response :no_content
    assert_typing_broadcast action: "stop"
  end

  test "invalid bot key is rejected" do
    assert_no_typing_broadcasts do
      post room_bot_typing_url(@room, "#{@bot.id}-bogus")
    end

    assert_response :redirect
  end

  test "invalid room is rejected" do
    assert_no_typing_broadcasts do
      post room_bot_typing_url(-1, @bot.bot_key)
    end

    assert_response :not_found
  end

  test "payload matches typing notification channel shape" do
    post room_bot_typing_url(@room, @bot.bot_key)

    assert_equal(
      { "action" => "start", "user" => { "id" => @bot.id, "name" => @bot.name } },
      typing_broadcasts.last
    )
  end

  private
    def assert_typing_broadcast(action:)
      assert_equal(
        { "action" => action, "user" => { "id" => @bot.id, "name" => @bot.name } },
        typing_broadcasts.last
      )
    end

    def assert_no_typing_broadcasts(&block)
      assert_no_changes -> { typing_broadcasts.size }, &block
    end

    def typing_broadcasts
      ActionCable.server.pubsub.broadcasts(TypingNotificationsChannel.broadcasting_for(@room)).collect { |payload| JSON.parse(payload) }
    end
end
