require "test_helper"

class Messages::ByBotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @room = rooms(:watercooler)
    @bot = users(:bender)
  end

  test "index returns room messages for valid bot key" do
    get room_bot_messages_url(@room, @bot.bot_key, format: :json), params: { limit: 2 }

    assert_response :success

    message = messages(:thirteenth)
    assert_equal(
      {
        "id" => message.id,
        "client_message_id" => "0013",
        "created_at" => message.created_at.iso8601(3),
        "updated_at" => message.updated_at.iso8601(3),
        "path" => room_at_message_path(@room, message),
        "creator" => { "id" => users(:jz).id, "name" => "JZ", "bot" => false },
        "body" => {
          "plain" => "When we are not sure, we are alive.",
          "html" => "<div class=\"trix-content\">\n  When we are not sure, we are alive.\n</div>\n"
        },
        "attachment" => nil
      },
      response.parsed_body["messages"].last
    )

    assert_equal(
      {
        "limit" => 2,
        "before_id" => messages(:twelfth).id,
        "after_id" => messages(:thirteenth).id
      },
      response.parsed_body["pagination"]
    )
  end

  test "index returns messages before an anchor message" do
    get room_bot_messages_url(@room, @bot.bot_key, format: :json), params: { before_id: messages(:thirteenth).id, limit: 2 }

    assert_response :success
    assert_equal [ messages(:eleventh).id, messages(:twelfth).id ], response.parsed_body["messages"].pluck("id")
  end

  test "index returns messages after an anchor message" do
    get room_bot_messages_url(@room, @bot.bot_key, format: :json), params: { after_id: messages(:eleventh).id, limit: 2 }

    assert_response :success
    assert_equal [ messages(:twelfth).id, messages(:thirteenth).id ], response.parsed_body["messages"].pluck("id")
  end

  test "index includes attachment metadata and download path" do
    message = @room.messages.create_with_attachment! \
      body: "A quiet moon.",
      creator: users(:david),
      client_message_id: "captioned-moon",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")

    get room_bot_messages_url(@room, @bot.bot_key, format: :json), params: { limit: 1 }

    attachment = response.parsed_body.dig("messages", 0, "attachment")

    assert_response :success
    assert_equal "moon.jpg", attachment["filename"]
    assert_equal "image/jpeg", attachment["content_type"]
    assert_equal message.attachment.byte_size, attachment["byte_size"]
    assert_equal rails_blob_path(message.attachment, disposition: "attachment", only_path: true), attachment["path"]
    assert_no_match %r{/storage/}, attachment["path"]
  end

  test "index clamps limit" do
    get room_bot_messages_url(@room, @bot.bot_key, format: :json), params: { limit: 0 }

    assert_response :success
    assert_equal 1, response.parsed_body["messages"].size
    assert_equal 1, response.parsed_body["pagination"]["limit"]
  end

  test "index rejects invalid bot key" do
    get room_bot_messages_url(@room, "#{@bot.id}-bogus", format: :json)

    assert_response :redirect
  end

  test "index rejects invalid room" do
    get room_bot_messages_url(-1, @bot.bot_key, format: :json)

    assert_response :not_found
  end

  test "index rejects inaccessible room" do
    get room_bot_messages_url(rooms(:designers), @bot.bot_key, format: :json)

    assert_response :not_found
  end

  test "create" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, @bot.bot_key), params: +"Hello Bot World!"
      assert_equal "Hello Bot World!", Message.last.plain_text_body
    end
  end

  test "create with UTF-8 content" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, @bot.bot_key), params: +"Hello 👋!"
      assert_equal "Hello 👋!", Message.last.plain_text_body
    end
  end

  test "create file" do
    assert_difference -> { Message.count }, +1 do
      post room_bot_messages_url(@room, @bot.bot_key), params: { attachment: fixture_file_upload("moon.jpg", "image/jpeg") }
      assert Message.last.attachment.present?
    end
  end

  test "create does not trigger a webhook to the sending bot if it mentions itself" do
    body = "<div>Hey #{mention_attachment_for(:bender)}</div>"

    assert_no_enqueued_jobs only: Bot::WebhookJob do
      post room_bot_messages_url(@room, @bot.bot_key), params: body
    end
  end

  test "create does not trigger a webhook to the sending bot in a direct room" do
    assert_no_enqueued_jobs only: Bot::WebhookJob do
      post room_bot_messages_url(rooms(:bender_and_kevin), @bot.bot_key), params: +"Talking to myself again!"
    end
  end

  test "create can't be abused to post messages as any user" do
    user = users(:kevin)
    bot_key = "#{user.id}-"

    assert_no_difference -> { Message.count } do
      post room_bot_messages_url(rooms(:bender_and_kevin), bot_key), params: "Hello 👋!"
    end

    assert_response :redirect
  end

  test "denied index" do
    get room_messages_url(@room, bot_key: @bot.bot_key, format: :json)
    assert_response :forbidden
  end
end
