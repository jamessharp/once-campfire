require "application_system_test_case"

class SendingMessagesTest < ApplicationSystemTestCase
  setup do
    sign_in "jz@37signals.com"
    join_room rooms(:designers)
  end

  test "sending messages between two users" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)
    end

    join_room rooms(:designers)
    send_message "Is this thing on?"

    using_session("Kevin") do
      join_room rooms(:designers)
      assert_message_text "Is this thing on?"

      send_message "👍👍"
    end

    join_room rooms(:designers)
    assert_message_text "👍👍"
  end

  test "sending a caption with multiple attachments" do
    attach_file "Attach a file", [ file_fixture("black_hole.jpg"), file_fixture("moon.jpg") ], make_visible: true

    send_message "A quiet moon."

    assert_selector ".message__attachment", minimum: 2
    assert_message_text "A quiet moon.", count: 1

    messages = rooms(:designers).messages.ordered.last(2)

    assert_equal 2, messages.count(&:attachment?)
    assert_equal 1, messages.count { |message| message.body.to_plain_text == "A quiet moon." }

    captioned_message = messages.detect { |message| message.body.to_plain_text == "A quiet moon." }

    within_message captioned_message do
      reveal_message_actions
      find(".message__edit-btn").click
      fill_in_rich_text_area "message_body", with: "A louder moon."
      click_on "Save changes"
    end

    assert_message_text "A quiet moon.", count: 0
    assert_message_text "A louder moon.", count: 1
    assert_selector ".message__attachment", minimum: 2
  end

  test "editing messages" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)
    end

    within_message messages(:third) do
      reveal_message_actions
      find(".message__edit-btn").click
      fill_in_rich_text_area "message_body", with: "Redacted!"
      click_on "Save changes"
    end

    using_session("Kevin") do
      join_room rooms(:designers)

      assert_message_text "Redacted!"
    end
  end

  test "deleting messages" do
    using_session("Kevin") do
      sign_in "kevin@37signals.com"
      join_room rooms(:designers)

      assert_message_text "Third time's a charm."
    end

    within_message messages(:third) do
      reveal_message_actions
      find(".message__edit-btn").click

      accept_confirm do
        click_on "Delete message"
      end
    end

    using_session("Kevin") do
      assert_message_text "Third time's a charm.", count: 0
    end
  end
end
