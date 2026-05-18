require "test_helper"

class WebhookTest < ActiveSupport::TestCase
  include ActionDispatch::TestProcess

  test "payload" do
    message = messages(:first)
    message_path = Rails.application.routes.url_helpers.room_at_message_path(message.room, message)
    bot_messages_path = Rails.application.routes.url_helpers.room_bot_messages_path(message.room, users(:bender).bot_key)

    WebMock.stub_request(:post, webhooks(:bender).url).
      with(body: hash_including(
        user: { id: message.creator.id, name: message.creator.name },
        room: { id: message.room.id, name: message.room.name, path: bot_messages_path },
        message: { id: message.id, body: { html: "First post!", plain: "First post!" }, path: message_path },
      ))

    response = webhooks(:bender).deliver(messages(:first))
    assert_equal 200, response.code.to_i
  end

  test "payload includes attachment metadata without exposing storage paths" do
    message = rooms(:watercooler).messages.create_with_attachment! \
      body: "A quiet moon.",
      creator: users(:david),
      client_message_id: "captioned-moon",
      attachment: fixture_file_upload("moon.jpg", "image/jpeg")

    payload = nil
    WebMock.stub_request(:post, webhooks(:bender).url).
      with { |request| payload = JSON.parse(request.body); true }.
      to_return(status: 200, body: "", headers: {})

    response = webhooks(:bender).deliver(message)
    attachment = payload.fetch("message").fetch("attachment")

    assert_equal 200, response.code.to_i
    assert_equal "A quiet moon.", payload.dig("message", "body", "plain")
    assert_equal "moon.jpg", attachment["filename"]
    assert_equal "image/jpeg", attachment["content_type"]
    assert_equal message.attachment.byte_size, attachment["byte_size"]
    assert_equal Rails.application.routes.url_helpers.rails_blob_path(message.attachment, disposition: "attachment", only_path: true), attachment["path"]
    assert_no_match %r{/storage/}, attachment["path"]
  end

  test "delivery" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: "", headers: {})
    response = webhooks(:bender).deliver(messages(:first))
    assert_equal 200, response.code.to_i
  end

  test "delivery with OK text reply" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: "Hello back!", headers: { "Content-Type" => "text/plain" })
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert_equal "Hello back!", reply_message.body.to_plain_text
  end

  test "delivery with OK attachment reply" do
    WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 200, body: file_fixture("moon.jpg"), headers: { "Content-Type" => "image/jpeg" })
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert reply_message.attachment.present?
  end

  test "delivery with error reply" do
    assert_no_difference -> { Message.count } do
      WebMock.stub_request(:post, webhooks(:bender).url).to_return(status: 500, body: "Internal Error!", headers: {})
      response = webhooks(:bender).deliver(messages(:first))
    end
  end

  test "delivery that times out" do
    Webhook.any_instance.stubs(:post).raises(Net::OpenTimeout)
    response = webhooks(:bender).deliver(messages(:first))

    reply_message = Message.last
    assert_equal "Failed to respond within 7 seconds", reply_message.body.to_plain_text
  end
end
