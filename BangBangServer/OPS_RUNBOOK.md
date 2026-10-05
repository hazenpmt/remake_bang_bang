# BangBang Server operations runbook

## Production gate

`NODE_ENV=production` intentionally refuses to start unless all of these are set:

- `RATE_LIMIT_BACKEND=redis` and `REDIS_URL` points to a shared Redis service;
- `ALLOWED_ORIGIN` is the exact public game/web origin, never `*`;
- `WEB_PROXY_SECRET` has at least 32 characters so only the trusted gateway can
  forward the real client IP;
- `BATTLE_PUBLIC_REALTIME_URL` is a full `wss://.../api/realtime/battle` URL;
- `METRICS_ENABLED=true` and `METRICS_BEARER_TOKEN` has at least 32 characters.

Use a Redis account restricted to the rate-limit prefix, enable authentication,
TLS (`rediss://`) and persistence/replication in the managed Redis service. Loss
of Redis fails closed with HTTP 503 or WebSocket 1013 instead of silently giving
each application node a fresh local quota. Local development and automated tests
can keep `RATE_LIMIT_BACKEND=memory`.

## Health, metrics and alerts

- `GET /health/live`: process is alive; it does not touch dependencies.
- `GET /health/ready`: PostgreSQL and rate limiter are ready and the process is
  not draining. Load balancers must route traffic only while this returns 200.
- `GET /metrics`: Prometheus text, disabled unless `METRICS_ENABLED=true` and
  protected by `Authorization: Bearer <METRICS_BEARER_TOKEN>`.
- Import `ops/prometheus-alerts.yml` into Prometheus and route its alerts through
  Alertmanager to the real on-call channel.

Never publish `/metrics` directly to the Internet. The reverse proxy must allow
it only from the monitoring network. Each HTTP response includes `X-Request-Id`
for log correlation. During graceful shutdown readiness becomes 503 before the
socket server, match checkpoints, telemetry queue and database pool close.

## Security telemetry

`security_events` is append-only and indexed by time, severity, type and account.
The asynchronous writer batches events and bounds its RAM queue. Details are
depth/size limited; keys resembling password, token, session, cookie, ticket or
secret are redacted. Source IP is stored only as HMAC-SHA256.

The server records authentication/authorization failures, rate-limit violations,
invalid/oversized requests, WebSocket handshake/message abuse, binary frames and
battle sequence/protocol failures. Admins can inspect recent events through
`GET /api/admin/security-events`; `/api/admin/overview` includes serious events
from the last hour plus queue/drop health.

An event is evidence for review, not proof of cheating. Automatic permanent bans
must not be based on a single client/network anomaly. Alert on dropped telemetry,
critical events and bursts of high-severity events using the supplied rules.

## Backup and restore

Create a custom-format PostgreSQL backup, SHA-256 manifest and immediately prove
it can restore into an isolated temporary PostgreSQL cluster:

```powershell
npm run backup-and-verify
```

The command never grants `CREATEDB` to the runtime account. It launches a
temporary PostgreSQL on a random loopback port, restores the archive, compares
core row counts and verifies append-only audit triggers, then stops and removes
only that generated cluster. The verified `.dump` and `.manifest.json` remain in
`backups/`.

Schedule the command daily outside peak hours. Copy each successful pair to an
encrypted, versioned off-machine/object-storage destination before applying local
retention. Recommended policy: 7 daily, 5 weekly, 12 monthly copies, with object
lock for the financial/audit backup set. Never commit backups or `.env` to source
control. Run an isolated restore drill after every schema change and at least
monthly in production.

## Failover checklist

1. Load balancer removes any node whose `/health/ready` is not 200.
2. A replacement node starts with the same PostgreSQL/Redis and unique
   `BATTLE_NODE_ID`/public WSS URL.
3. Expired worker lease is taken over with a higher `state_epoch`; old tickets and
   stale workers fail closed through epoch fencing.
4. Client HTTP fallback continues while it requests a new one-use realtime ticket;
   reconnect receives a full snapshot before deltas resume.
5. Verify no duplicate economy/reward ledger rows, check security telemetry drops,
   then retain incident logs and request IDs.

The automated battle-memory PostgreSQL smoke already exercises lease takeover,
checkpoint recovery and idempotent replay. Perform the real load-balancer/node
drill in staging before every production release because DNS, TLS, Redis and the
gateway are external deployment state, not source-code behavior.
