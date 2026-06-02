# LinkUP Presence API

This service is the rendezvous layer for LinkUP. It does not store chat messages.

What it does:
- stores live peer presence records so clients know where a device can currently be reached
- lets clients check whether a known peer is online
- relays lightweight direct signals such as `availability` or `history_request` to a peer callback URL when that peer is online

What it does not do:
- persist message bodies
- act as a chat history database
- keep offline messages on the server

## Presence model

Each client registers a live presence record containing:
- `peerId`: stable user/contact identifier, for example the app's contact key
- `deviceId`: specific device session identifier
- `address`: the address where the messenger can be reached directly
- `callbackUrl`: optional webhook-style URL for availability/history sync signals
- `capabilities`: current direct relay and history sync support

Records expire automatically based on client-provided TTL.

## API

### `POST /api/presence/upsert`

Registers or refreshes a presence record.

Example body:

```json
{
  "peerId": "linkup:abcd1234",
  "deviceId": "phone-main",
  "address": "https://198.51.100.10:9443",
  "callbackUrl": "https://198.51.100.10:9443/linkup/signal",
  "ttlSeconds": 120,
  "capabilities": {
    "historySync": true,
    "directRelay": true
  }
}
```

### `GET /api/presence/:peerId`

Returns the currently online devices for one peer.

### `POST /api/presence/lookup`

Bulk lookup for multiple peer IDs.

Example body:

```json
{
  "peerIds": ["linkup:alice", "linkup:bob"]
}
```

### `DELETE /api/presence/:peerId/:deviceId`

Removes a device from presence.

### `POST /api/notify/direct`

Relays a lightweight direct signal to currently online devices for a peer.

Supported kinds:
- `availability`
- `history_request`

Example body:

```json
{
  "toPeerId": "linkup:bob",
  "fromPeerId": "linkup:alice",
  "fromDeviceId": "desktop-main",
  "fromAddress": "https://203.0.113.24:9443",
  "fromContactKey": "linkup:alice",
  "kind": "history_request",
  "note": "Ask for deferred messages when online"
}
```

## Vercel deployment

Deploy this folder as the Vercel project root.

Recommended environment variables:
- `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_REST_TOKEN`
- `PUBLIC_BASE_URL`

Without Upstash Redis, the service falls back to in-memory storage, which is suitable only for local development.

## Docker

Build:

```bash
docker build -t linkup-presence-api .
```

Run:

```bash
docker run --rm -p 3000:3000 --env-file .env linkup-presence-api
```