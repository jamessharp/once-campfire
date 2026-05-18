# Once Campfire Bot API Reference

## URL Derivation

Given a bot message URL:

```text
/rooms/1/<bot-key>/messages
```

derive:

```text
GET    /rooms/1/<bot-key>.json
GET    /rooms/1/<bot-key>/messages.json?limit=50
POST   /rooms/1/<bot-key>/messages
POST   /rooms/1/<bot-key>/typing
DELETE /rooms/1/<bot-key>/typing
```

If the webhook only provides a relative path, resolve it against the configured Campfire origin.

## Incoming Webhook Payload

Campfire posts JSON to the bot's configured webhook URL:

```json
{
  "user": { "id": 42, "name": "Kevin" },
  "room": {
    "id": 1,
    "name": "All Talk",
    "path": "/rooms/1/<bot-key>/messages"
  },
  "message": {
    "id": 123,
    "body": {
      "html": "<div class=\"trix-content\">...</div>",
      "plain": "Can you check this?"
    },
    "path": "/rooms/1/@123"
  }
}
```

`room.path` is the write endpoint for replies. Build read and typing endpoints from it.

## Read Room

```sh
curl -i "https://campfire.example.com/rooms/1/<bot-key>.json"
```

Response:

```json
{
  "room": {
    "id": 1,
    "name": "All Talk",
    "type": "closed",
    "path": "/rooms/1",
    "messages_path": "/rooms/1/<bot-key>/messages",
    "users": [
      { "id": 7, "name": "Bender Bot", "bot": true },
      { "id": 42, "name": "Kevin", "bot": false }
    ]
  }
}
```

## Read Messages

```sh
curl -i "https://campfire.example.com/rooms/1/<bot-key>/messages.json?limit=50"
curl -i "https://campfire.example.com/rooms/1/<bot-key>/messages.json?after_id=123"
curl -i "https://campfire.example.com/rooms/1/<bot-key>/messages.json?before_id=123"
```

Messages are returned oldest to newest within the selected page. `limit` defaults to 50 and is clamped to 1-100.

Response:

```json
{
  "messages": [
    {
      "id": 123,
      "client_message_id": "0013",
      "created_at": "2026-05-18T09:31:14.123Z",
      "updated_at": "2026-05-18T09:31:14.123Z",
      "path": "/rooms/1/@123",
      "creator": { "id": 42, "name": "Kevin", "bot": false },
      "body": {
        "plain": "Can you check this?",
        "html": "<div class=\"trix-content\">Can you check this?</div>"
      },
      "attachment": null
    }
  ],
  "pagination": {
    "limit": 50,
    "before_id": 123,
    "after_id": 123
  }
}
```

Attachment messages use:

```json
{
  "filename": "image.png",
  "content_type": "image/png",
  "byte_size": 12345
}
```

## Send Typing

```sh
curl -i -X POST "https://campfire.example.com/rooms/1/<bot-key>/typing"
curl -i -X DELETE "https://campfire.example.com/rooms/1/<bot-key>/typing"
```

Both return `204 No Content` on success. Repeat `POST` every 3-4 seconds for long-running responses, and always send `DELETE` when finished or aborted.

## Send Messages

Text reply:

```sh
curl -i -X POST \
  --data-binary "Here is what I found." \
  "https://campfire.example.com/rooms/1/<bot-key>/messages"
```

Attachment reply:

```sh
curl -i -F "attachment=@/path/to/file" \
  "https://campfire.example.com/rooms/1/<bot-key>/messages"
```

Success is `201 Created` with a `Location` header for the message.

## Error Handling

- `200 OK`: JSON room/message reads.
- `201 Created`: message or attachment posted.
- `204 No Content`: typing start/stop accepted.
- `302` or other redirect to session: invalid/missing bot key or unauthenticated path. Treat as auth failure.
- `404 Not Found`: invalid room id or room not accessible to this bot on bot read/typing endpoints.

Disable automatic redirect following when checking auth-sensitive calls so a login page is not misinterpreted as a successful API response.
