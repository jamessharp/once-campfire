class Messages::ByBotsController < MessagesController
  DEFAULT_LIMIT = 50
  MAX_LIMIT = 100

  allow_bot_access only: %i[ index create ]

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  def index
    render json: {
      messages: messages.map { |message| serialize_message(message) },
      pagination: {
        limit: limit,
        before_id: messages.first&.id,
        after_id: messages.last&.id
      }
    }
  end

  def create
    super
    head :created, location: message_url(@message) unless performed?
  end

  private
    def messages
      @messages ||= find_messages
    end

    def find_messages
      case
      when before_message_id.present?
        messages_scope.before(anchor_message(before_message_id)).ordered.last(limit)
      when after_message_id.present?
        messages_scope.after(anchor_message(after_message_id)).ordered.first(limit)
      else
        messages_scope.ordered.last(limit)
      end
    end

    def messages_scope
      @room.messages.with_creator.with_attachment_details
    end

    def anchor_message(message_id)
      @room.messages.find(message_id)
    end

    def before_message_id
      params[:before_id] || params[:before]
    end

    def after_message_id
      params[:after_id] || params[:after]
    end

    def limit
      @limit ||= params.fetch(:limit, DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
    end

    def serialize_message(message)
      {
        id: message.id,
        client_message_id: message.client_message_id,
        created_at: message.created_at.iso8601(3),
        updated_at: message.updated_at.iso8601(3),
        path: room_at_message_path(message.room, message),
        creator: serialize_user(message.creator),
        body: {
          plain: message.plain_text_body,
          html: message.body.body.to_s
        },
        attachment: serialize_attachment(message)
      }
    end

    def serialize_user(user)
      {
        id: user.id,
        name: user.name,
        bot: user.bot?
      }
    end

    def serialize_attachment(message)
      if message.attachment?
        {
          filename: message.attachment.filename.to_s,
          content_type: message.attachment.content_type,
          byte_size: message.attachment.byte_size,
          path: rails_blob_path(message.attachment, disposition: "attachment", only_path: true)
        }
      end
    end

    def message_params
      if params[:attachment]
        params.permit(:attachment)
      else
        reading(request.body) { |body| { body: body } }
      end
    end

    def reading(io)
      io.rewind
      yield io.read.force_encoding("UTF-8")
    ensure
      io.rewind
    end

    def render_not_found
      head :not_found
    end
end
