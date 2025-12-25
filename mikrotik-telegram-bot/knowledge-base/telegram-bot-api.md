# Telegram Bot API Knowledge Base

> **Version**: Bot API 9.2 (August 2025)
> **Source**: [Official Documentation](https://core.telegram.org/bots/api)
> **Changelog**: [API Changelog](https://core.telegram.org/bots/api-changelog)

---

## Table of Contents

1. [Core Concepts](#core-concepts)
2. [Authentication](#authentication)
3. [Update Methods](#update-methods)
4. [Messaging Methods](#messaging-methods)
5. [Inline Keyboards](#inline-keyboards)
6. [Callback Queries](#callback-queries)
7. [Rate Limits](#rate-limits)
8. [File Handling](#file-handling)
9. [Webhooks vs Long Polling](#webhooks-vs-long-polling)
10. [Error Handling](#error-handling)
11. [Best Practices](#best-practices)
12. [Recent API Changes](#recent-api-changes)

---

## Core Concepts

### Bot Token

- Format: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`
- Obtained from [@BotFather](https://t.me/BotFather)
- Keep secret - never commit to repositories
- Can be revoked and regenerated via BotFather

### Base URL

```
https://api.telegram.org/bot<token>/METHOD_NAME
```

### Request Format

- HTTP methods: GET or POST
- Content-Type: `application/json` or `multipart/form-data` (for files)
- All methods are case-insensitive
- UTF-8 encoding required

---

## Authentication

### Creating a Bot

1. Message [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Choose display name and username (must end in `bot`)
4. Receive token

### Bot Settings via BotFather

| Command | Description |
|---------|-------------|
| `/setname` | Change display name |
| `/setdescription` | Set bot description |
| `/setabouttext` | Set about text |
| `/setuserpic` | Set profile picture |
| `/setcommands` | Define command list |
| `/setprivacy` | Toggle privacy mode |
| `/revoke` | Regenerate token |

---

## Update Methods

### getUpdates (Long Polling)

```http
GET /bot<token>/getUpdates?offset=<id>&limit=100&timeout=30
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `offset` | Integer | No | ID of first update to return |
| `limit` | Integer | No | Max updates (1-100, default 100) |
| `timeout` | Integer | No | Long polling timeout in seconds |
| `allowed_updates` | Array | No | Update types to receive |

**Offset Handling**: Set `offset = last_update_id + 1` to acknowledge receipt.

### setWebhook

```http
POST /bot<token>/setWebhook
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | String | Yes | HTTPS URL for updates |
| `certificate` | InputFile | No | Self-signed certificate |
| `ip_address` | String | No | Fixed IP for webhook |
| `max_connections` | Integer | No | 1-100 (default 40) |
| `allowed_updates` | Array | No | Update types to receive |
| `secret_token` | String | No | Header verification token |

**Supported Ports**: 443, 80, 88, 8443

### deleteWebhook

```http
POST /bot<token>/deleteWebhook?drop_pending_updates=true
```

---

## Messaging Methods

### sendMessage

```http
POST /bot<token>/sendMessage
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `chat_id` | Integer/String | Yes | Target chat ID or @username |
| `text` | String | Yes | Message text (1-4096 chars) |
| `parse_mode` | String | No | `MarkdownV2`, `HTML`, `Markdown` |
| `entities` | Array | No | Special entities in message |
| `link_preview_options` | Object | No | Link preview settings |
| `disable_notification` | Boolean | No | Send silently |
| `protect_content` | Boolean | No | Prevent forwarding/saving |
| `reply_parameters` | Object | No | Reply settings |
| `reply_markup` | Object | No | Keyboard markup |

### editMessageText

```http
POST /bot<token>/editMessageText
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `chat_id` | Integer/String | Conditional | Required if inline_message_id not used |
| `message_id` | Integer | Conditional | Required if inline_message_id not used |
| `inline_message_id` | String | Conditional | Required for inline messages |
| `text` | String | Yes | New message text |
| `parse_mode` | String | No | Formatting mode |
| `reply_markup` | Object | No | New inline keyboard |

**Note**: Business messages can only be edited within 48 hours.

### deleteMessage

```http
POST /bot<token>/deleteMessage
```

- Can delete messages up to 48 hours old
- In supergroups: can delete any message (with permissions)
- In private chats: can only delete own messages

### Other Send Methods

| Method | Description | Max Size |
|--------|-------------|----------|
| `sendPhoto` | Send photos | 10 MB |
| `sendVideo` | Send video files | 50 MB |
| `sendDocument` | Send files | 50 MB |
| `sendAudio` | Send audio | 50 MB |
| `sendVoice` | Send voice message | 50 MB |
| `sendLocation` | Send location | - |
| `sendPoll` | Create poll | 2-12 options |

---

## Inline Keyboards

### InlineKeyboardMarkup

```json
{
  "inline_keyboard": [
    [
      {"text": "Button 1", "callback_data": "btn1"},
      {"text": "Button 2", "callback_data": "btn2"}
    ],
    [
      {"text": "URL", "url": "https://example.com"}
    ]
  ]
}
```

### InlineKeyboardButton Types

| Field | Description |
|-------|-------------|
| `text` | Button label (required) |
| `callback_data` | Data sent to bot (1-64 bytes) |
| `url` | URL to open |
| `web_app` | Web App to launch |
| `login_url` | Login URL for Telegram Login |
| `switch_inline_query` | Switch to inline mode |
| `switch_inline_query_current_chat` | Inline in current chat |
| `pay` | Payment button (first button only) |

### Callback Data Best Practices

1. **Unique data**: Each button should have unique callback_data
2. **Size limit**: 1-64 bytes UTF-8
3. **Structure**: Use prefixes like `action:param` (e.g., `menu:main`, `toggle:cpu`)
4. **Parsing**: Extract data with string operations

```routeros
# RouterOS example
:local Action [:pick $CallbackData 0 [:find $CallbackData ":"]]
:local Param [:pick $CallbackData ([:find $CallbackData ":"] + 1) [:len $CallbackData]]
```

---

## Callback Queries

### answerCallbackQuery

**CRITICAL**: Always answer callback queries to stop the loading animation.

```http
POST /bot<token>/answerCallbackQuery
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `callback_query_id` | String | Yes | Query ID from update |
| `text` | String | No | Notification text (0-200 chars) |
| `show_alert` | Boolean | No | Show alert instead of notification |
| `url` | String | No | URL to open |
| `cache_time` | Integer | No | Cache time in seconds |

### Callback Query Object

```json
{
  "id": "123456789",
  "from": { "id": 12345, "first_name": "User" },
  "message": { ... },
  "chat_instance": "abc123",
  "data": "callback_data_here"
}
```

---

## Rate Limits

### Message Limits

| Scenario | Limit |
|----------|-------|
| Different chats | 30 messages/second |
| Same private chat | 1 message/second |
| Same group chat | 20 messages/minute |
| Message edits (group) | ~20 edits/minute |

### Paid Broadcasts

- Enable via @BotFather
- Up to 1000 messages/second
- Cost: 0.1 Stars per message over free tier
- Requirements: 100,000 Stars balance, 100,000 MAU

### Handling 429 Errors

```json
{
  "ok": false,
  "error_code": 429,
  "description": "Too Many Requests: retry after 35",
  "parameters": {
    "retry_after": 35
  }
}
```

**Solution**: Wait `retry_after` seconds, then retry.

---

## File Handling

### Size Limits

| Operation | Limit |
|-----------|-------|
| Download (getFile) | 20 MB |
| Upload (standard) | 50 MB |
| Local Bot API Server | 2000 MB |

### File Methods

```http
# Get file path
GET /bot<token>/getFile?file_id=<file_id>

# Download file
GET https://api.telegram.org/file/bot<token>/<file_path>
```

### File ID Reuse

- File IDs are unique per bot
- Can reuse file_id to send same file without re-uploading
- File IDs don't expire

---

## Webhooks vs Long Polling

### Comparison

| Aspect | Webhook | Long Polling |
|--------|---------|--------------|
| **Latency** | Immediate | Polling interval delay |
| **Setup** | Requires HTTPS server | Simple, no server needed |
| **Resources** | Only active on updates | Constant connection |
| **Scaling** | Better for high traffic | Simpler for low traffic |
| **Development** | Harder to debug locally | Easy local development |

### Webhook Requirements

1. **HTTPS only** (TLS 1.2+)
2. **Valid SSL certificate** (or self-signed with upload)
3. **Ports**: 443, 80, 88, or 8443
4. **IPv4 only** (IPv6 not supported)

### Webhook Security

```http
# Set webhook with secret token
POST /bot<token>/setWebhook
{
  "url": "https://example.com/webhook",
  "secret_token": "your-secret-token"
}
```

Verify header: `X-Telegram-Bot-Api-Secret-Token`

### Telegram IP Ranges

Whitelist these subnets:
- `149.154.160.0/20`
- `91.108.4.0/22`

---

## Error Handling

### Common Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| 400 | Bad Request | Check parameters |
| 401 | Unauthorized | Invalid token |
| 403 | Forbidden | Bot blocked/no access |
| 404 | Not Found | Invalid method/chat |
| 409 | Conflict | Webhook/polling conflict |
| 429 | Too Many Requests | Wait retry_after seconds |

### Error Response Format

```json
{
  "ok": false,
  "error_code": 400,
  "description": "Bad Request: message text is empty"
}
```

---

## Best Practices

### 1. Always Answer Callbacks

```routeros
# Answer immediately to stop loading animation
/tool/fetch url=$AnswerUrl http-data=("callback_query_id=" . $QueryId)
```

### 2. Edit Instead of Send

Reduce message clutter by editing existing messages:

```routeros
# Edit message instead of sending new
/tool/fetch url=($APIUrl . "/editMessageText") http-data=$EditData
```

### 3. Use Structured Callback Data

```
# Good patterns
menu:main
toggle:cpu:on
script:mod-001:install
page:scripts:2

# Bad patterns
1234567890  # Opaque
main        # No namespace
```

### 4. Handle Rate Limits

```routeros
:onerror RateErr {
  /tool/fetch url=$Url http-data=$Data
} do={
  :if ($RateErr ~ "429") do={
    :delay 30s
    # Retry
  }
}
```

### 5. Validate Input

- Check chat_id format
- Sanitize user input
- Validate callback_data prefixes
- Escape Markdown characters

### 6. Use parse_mode Consistently

Choose one format and stick with it:

| Format | Escape Characters |
|--------|-------------------|
| `Markdown` | `_*\`` ` |
| `MarkdownV2` | `_*[]()~\`>#+-=\|{}.!` |
| `HTML` | `<>&` |

---

## Recent API Changes

### Bot API 9.2 (August 2025)

- Checklists support
- Direct messages in channels
- Suggested posts for channels
- `can_manage_direct_messages` admin right

### Bot API 9.1 (July 2025)

- `sendChecklist` and `editMessageChecklist`
- Maximum poll options increased to 12
- `getMyStarBalance` method

### Bot API 9.0 (April 2025)

- Business account expansion
- Story posting (`postStory`, `editStory`, `deleteStory`)
- Gift management methods
- Mini App DeviceStorage and SecureStorage

### Bot API 8.0 (November 2024)

- Full-screen Mini Apps
- Home screen shortcuts
- Emoji status management
- Geolocation access

---

## RouterOS-Specific Notes

### URL Encoding

Use the `UrlEncode` function for all user-generated content:

```routeros
:global UrlEncode do={
  :local Input [ :tostr $1 ];
  # Encode special characters
  :return $Encoded;
}
```

### Certificate Handling

```routeros
:if ([$CertificateAvailable "ISRG Root X1"] = false) do={
  /tool/fetch check-certificate=no url=$Url http-data=$Data
} else={
  /tool/fetch check-certificate=yes-without-crl url=$Url http-data=$Data
}
```

### Timeout Handling

RouterOS fetch has a 10-second default timeout. For long polling:

```routeros
/tool/fetch mode=https url=$Url output=user as-value timeout=30s
```

---

## References

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Bot API Changelog](https://core.telegram.org/bots/api-changelog)
- [Bots FAQ](https://core.telegram.org/bots/faq)
- [Webhooks Guide](https://core.telegram.org/bots/webhooks)
- [Inline Bots](https://core.telegram.org/bots/2-0-intro)
- [@BotNews](https://t.me/BotNews) - Official updates
- [@BotTalk](https://t.me/BotTalk) - Developer community
