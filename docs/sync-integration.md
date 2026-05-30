# Sync Integration Guide

How to add Cloudflare D1-backed sync to any app (web or Swift).

## Architecture

```
App (your JSON data)
  └── SyncClient (JS or Swift)
        │  HTTPS
        ▼
  Cloudflare Worker ─── D1 database
```

The SyncClient is a thin class that moves opaque `{key: value}` blobs. It knows nothing about your app's schema. Your app remains the source of truth locally; sync is additive.

---

## 1. Server Setup (one-time per Cloudflare account)

```bash
npx wrangler login
npx wrangler d1 create sync-db
# → copy the returned database_id
```

Create `sync-server/` (copy from this repo's `sync-server/` directory):

1. Copy all files from `sync-server/` to your new project
2. Paste the `database_id` into `sync-server/wrangler.toml`
3. Apply the schema:

```bash
npx wrangler d1 execute sync-db --remote --file sync-server/migrations/001_schema.sql
```

4. Deploy:

```bash
npx wrangler deploy --config sync-server/wrangler.toml
```

5. Create a token for your app:

```bash
curl -X POST https://<your-worker>.workers.dev/token/new \
  -H "Content-Type: application/json" \
  -d '{"label":"<AppName>"}'
# → returns {"token":"..."} — paste this into the app
```

---

## 2. Adding SyncClient to a Web App

### Option A: Inline (recommended for single-file apps)

Copy the `SyncClient` class (105 lines from `index.html`'s inline script) directly into your HTML. The external script approach (`<script src="sync-client.js">`) does not work on mobile `file://` pages.

### Option B: External script (for hosted apps)

Copy `sync-client.js` from this repo, add a script tag:

```html
<script src="sync-client.js"></script>
```

### Integration Pattern

```js
// On app startup:
loadLocalData();                        // fast, works offline
if (syncClient) {
  var remote = await syncClient.pull(); // slow, may fail
  if (remote) mergeIntoAppData(remote); // server wins on conflict
  saveData();
  render();
}

// On any data change:
function saveData() {
  writeToLocalStorage(appData);
  if (syncClient) {
    debouncedPush('key1', appData.key1);
    debouncedPush('key2', appData.key2);
  }
}
```

### Data Validation Gotcha

When merging pulled data, validate each key's type. Common mistakes:

```js
for (var key in remoteData) {
  // people is an array; roster is a DICTIONARY (not array)
  if (key === 'people' && !Array.isArray(remoteData[key])) continue;
  if (key === 'roster' && (typeof remoteData[key] !== 'object' || remoteData[key] === null)) continue;
  // cycleStart may be null
  if (key === 'cycleStart' && remoteData[key] !== null && typeof remoteData[key] !== 'number') continue;
  appData[key] = remoteData[key];
}
```

---

## 3. Adding SyncClient to a Swift App

Copy `sync-client.swift` from this repo. Swift 5.5+, Foundation only.

```swift
let client = SyncClient(
  token: "<token>",
  endpoint: URL(string: "https://<your-worker>.workers.dev")!,
  device: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
  defaults: UserDefaults.standard
)

// On startup:
if let remote = try? await client.pull() {
  for (key, value) in remote {
    appData[key] = value
  }
}

// On changes:
try? await client.push(["people": peopleData, "roster": rosterData])
```

---

## 4. Conflict Handling

The protocol uses per-key optimistic concurrency. Each key has a monotonic version counter. When two devices push the same key:

1. First push accepted (version N → N+1)
2. Second push rejected (version doesn't match server's N+1)
3. Client re-pulls the key, merges locally, re-pushes

Your app can either:
- **Server wins** (simplest): overwrite local with pulled data
- **Manual merge**: show the conflict and let the user decide

The Councilor integration uses server-wins with automatic re-pull.

---

## 5. What to Copy Per New App

**Infrastructure (one-time):**
- `sync-server/` directory — deploy to Cloudflare

**Client code (per app):**
- Web: `SyncClient` class (inline or `sync-client.js`)
- Swift: `sync-client.swift`

**Per-app setup:**
- Create a new token via `/token/new`
- Store the endpoint (`https://<worker>.workers.dev`) as a constant
- Generate a persistent device ID (UUID in localStorage / `identifierForVendor`)

---

## 6. Known Pitfalls

| Pitfall | Lesson |
|---|---|
| External scripts on mobile | `<script src="">` doesn't load on `file://` — inline instead |
| Worker `device` variable | `handleSyncPush` needs `const device = ...` before logging — omission crashes the Worker with error 1101 |
| Roster is not an array | `Array.isArray(roster)` is `false` → check `typeof === 'object'` instead |
| `cycleStart` can be null | Validate with explicit `null` check before `typeof === 'number'` |
| Debounce timing | 2s debounce means changes don't sync instantly — intentional for batching |
| localStorage failure | `saveSyncConfig` can throw if storage is full — create SyncClient in memory first, then attempt save |

---

## 7. API Reference

### POST /token/new
- Creates a new sync token (32-char alphanumeric)
- Input: `{ "label": "AppName" }`
- Output: `{ "token": "..." }`

### POST /sync/pull
- Returns keys newer than client's known versions
- Input: `{ "token", "device", "versions": { "key": ver } }`
- Output: `{ "entries": [{ "key", "value", "ver }], "latest": { "key": ver } }`

### POST /sync/push
- Atomically updates keys with version check
- Input: `{ "token", "device", "entries": [{ "key", "value", "ver }] }`
- Output: `{ "resolved": [{ "key", "ver }], "conflicts": [{ "key", "detail" }] }`
