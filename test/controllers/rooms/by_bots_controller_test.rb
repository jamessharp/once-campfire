require "test_helper"

class Rooms::ByBotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @bot = users(:bender)
    @room = rooms(:watercooler)
  end

  test "show returns room details for valid bot key" do
    get room_bot_url(@room, @bot.bot_key, format: :json)

    assert_response :success

    assert_equal(
      {
        "room" => {
          "id" => @room.id,
          "name" => "All Talk",
          "type" => "closed",
          "path" => room_path(@room),
          "messages_path" => room_bot_messages_path(@room, @bot.bot_key),
          "users" => [
            { "id" => @bot.id, "name" => "Bender Bot", "bot" => true },
            { "id" => users(:david).id, "name" => "David", "bot" => false },
            { "id" => users(:jason).id, "name" => "Jason", "bot" => false }
          ]
        }
      },
      response.parsed_body
    )
  end

  test "invalid bot key is rejected" do
    get room_bot_url(@room, "#{@bot.id}-bogus", format: :json)

    assert_response :redirect
  end

  test "invalid room is rejected" do
    get room_bot_url(-1, @bot.bot_key, format: :json)

    assert_response :not_found
  end

  test "inaccessible room is rejected" do
    get room_bot_url(rooms(:designers), @bot.bot_key, format: :json)

    assert_response :not_found
  end
end
