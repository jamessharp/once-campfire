---
name: use-campfire-bot
description: >-
  Operate a Once Campfire bot or OpenClaw-style agent through Campfire's HTTP bot
  API. Use when Codex needs to implement, debug, or run a Campfire integration
  that receives bot webhooks, reads room/message context, sends bot replies or
  attachments, shows typing indicators, handles bot-key authentication, or
  derives bot endpoint URLs from Campfire message URLs.
---

# Use Campfire Bot

## Core Rules

- Use the HTTP bot endpoints. Do not connect the bot directly to ActionCable.
- Treat `bot_key` URLs as secrets. Avoid printing them in logs, chat, screenshots, or telemetry.
- Scope every action to the room in the webhook/configured URL. Bot access is membership-scoped; inaccessible rooms should be treated as unavailable.
- Use typing indicators while thinking or calling tools, and always send a stop signal in cleanup.
- Prefer reading recent room context before replying so the bot behaves like a participant, not a blind webhook responder.

## Workflow

1. Resolve the Campfire origin.
   - Webhooks include relative paths such as `/rooms/1/<bot-key>/messages`.
   - Combine those paths with the configured Campfire base URL, for example `https://campfire.example.com`.

2. Derive endpoint URLs from the message URL.
   - Message URL: `/rooms/:room_id/:bot_key/messages`
   - Typing URL: replace `/messages` with `/typing`
   - Room JSON URL: remove `/messages` and add `.json`
   - Messages JSON URL: add `.json` before the query string

3. Read room context.
   - Fetch `GET /rooms/:room_id/:bot_key/messages.json?limit=50` before composing non-trivial replies.
   - Use `after_id` to catch up after a known message and `before_id` to page older context.
   - Fetch `GET /rooms/:room_id/:bot_key.json` when room members, room type, or canonical paths matter.

4. Show typing during long work.
   - Send `POST /rooms/:room_id/:bot_key/typing` before work starts.
   - Repeat the start request every 3-4 seconds during long responses because browsers expire stale typing indicators after about 5 seconds.
   - Send `DELETE /rooms/:room_id/:bot_key/typing` in a `finally`/ensure block.

5. Send the reply.
   - Post plain UTF-8 text as the raw request body to `/rooms/:room_id/:bot_key/messages`.
   - Upload files as multipart form data with field name `attachment`.
   - Expect `201 Created` and use the `Location` header as the created message URL.

6. Handle errors deliberately.
   - Success responses are `200` for JSON reads, `201` for message creation, and `204` for typing.
   - Invalid bot keys follow Campfire's existing unauthenticated flow, usually a redirect to the session page. Do not follow redirects blindly and mistake the login page for success.
   - Invalid or inaccessible rooms return `404` on bot read and typing endpoints.

## Webhook Handling

Campfire webhooks are the event source. A webhook payload contains the sender, room, and triggering message, including `room.path`, which is the bot message endpoint for replies.

For shared rooms, Campfire currently sends bot webhooks when the bot is mentioned. For direct rooms that include the bot, Campfire sends webhooks for messages in that direct room. Do not assume there is a room-observation API beyond webhook delivery and explicit context reads.

When replying:

- Use `message.body.plain` as the primary user text.
- Use `message.body.html` only when formatting, mentions, or rich text details matter.
- Ignore messages authored by the same bot unless the task explicitly requires self-reflection.
- Avoid duplicate replies by checking recent context when retrying after a timeout or crash.

## API Reference

Read [references/api.md](references/api.md) when exact endpoints, response fields, curl examples, or status-code behavior are needed.
