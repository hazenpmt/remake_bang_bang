import { randomBytes } from "node:crypto";
import { writeFile } from "node:fs/promises";
import pg from "pg";
import { runMigrations } from "./migrations.js";

const { Client } = pg;
const host = "127.0.0.1";
const port = 5432;
const databaseName = "bangbang";
const appUser = "bangbang_app";

function promptSecret(label) {
  if (!process.stdin.isTTY) {
    throw new Error("Hãy chạy lệnh này trong cửa sổ Command Prompt.");
  }

  return new Promise((resolve) => {
    let value = "";
    process.stdout.write(label);
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.setEncoding("utf8");

    const finish = () => {
      process.stdin.setRawMode(false);
      process.stdin.pause();
      process.stdin.off("data", onData);
      process.stdout.write("\n");
      resolve(value);
    };

    const onData = (character) => {
      if (character === "\u0003") {
        process.stdout.write("\n");
        process.exit(130);
      }
      if (character === "\r" || character === "\n") {
        finish();
        return;
      }
      if (character === "\u007f" || character === "\b") {
        if (value.length > 0) {
          value = value.slice(0, -1);
          process.stdout.write("\b \b");
        }
        return;
      }
      if (character >= " ") {
        value += character;
        process.stdout.write("*");
      }
    };

    process.stdin.on("data", onData);
  });
}

const postgresPassword = await promptSecret(
  "Nhập mật khẩu user postgres đã đặt lúc cài (sẽ không hiện chữ): ",
);
const appPassword = randomBytes(24).toString("base64url");
const registrationHashSecret = randomBytes(32).toString("base64url");
const rateLimitKeySecret = randomBytes(32).toString("base64url");

const admin = new Client({
  host,
  port,
  database: "postgres",
  user: "postgres",
  password: postgresPassword,
});

try {
  await admin.connect();

  const roleResult = await admin.query(
    "SELECT 1 FROM pg_roles WHERE rolname = $1",
    [appUser],
  );
  if (roleResult.rowCount === 0) {
    await admin.query(
      `CREATE ROLE bangbang_app LOGIN PASSWORD '${appPassword}'`,
    );
  } else {
    await admin.query(
      `ALTER ROLE bangbang_app WITH LOGIN PASSWORD '${appPassword}'`,
    );
  }

  const databaseResult = await admin.query(
    "SELECT 1 FROM pg_database WHERE datname = $1",
    [databaseName],
  );
  if (databaseResult.rowCount === 0) {
    await admin.query("CREATE DATABASE bangbang OWNER bangbang_app");
  } else {
    await admin.query("ALTER DATABASE bangbang OWNER TO bangbang_app");
  }
} catch (error) {
  console.error(
    "Không thể thiết lập PostgreSQL. Hãy kiểm tra lại mật khẩu postgres.",
  );
  console.error(error.message);
  process.exitCode = 1;
} finally {
  await admin.end().catch(() => {});
}

if (process.exitCode) {
  process.exit();
}

const databaseUrl =
  `postgresql://${appUser}:${encodeURIComponent(appPassword)}` +
  `@${host}:${port}/${databaseName}`;
const envContent = [
  "HOST=127.0.0.1",
  "PORT=8080",
  `DATABASE_URL=${databaseUrl}`,
  "SESSION_DAYS=30",
  "ADMIN_SESSION_HOURS=8",
  "ALLOWED_ORIGIN=*",
  "MAX_ONLINE_PLAYERS=100",
  "PRESENCE_LEASE_SECONDS=90",
  "HEARTBEAT_INTERVAL_SECONDS=20",
  "QUEUE_TICKET_SECONDS=900",
  "QUEUE_POLL_SECONDS=3",
  "LOGIN_RATE_LIMIT=8",
  "LOGIN_RATE_WINDOW_SECONDS=60",
  "LOGIN_ACCOUNT_RATE_LIMIT=10",
  "LOGIN_ACCOUNT_RATE_WINDOW_SECONDS=300",
  "QUEUE_POLL_RATE_LIMIT=30",
  "REGISTRATION_COOLDOWN_SECONDS=10800",
  "REGISTRATION_IP_LIMIT=5",
  `REGISTRATION_HASH_SECRET=${registrationHashSecret}`,
  `RATE_LIMIT_KEY_SECRET=${rateLimitKeySecret}`,
  "RATE_LIMIT_BACKEND=memory",
  "REDIS_URL=",
  "METRICS_ENABLED=false",
  "METRICS_BEARER_TOKEN=",
  "TRUST_PROXY=false",
  "",
].join("\n");
await writeFile(new URL("../.env", import.meta.url), envContent, "utf8");
const appClient = new Client({ connectionString: databaseUrl });

try {
  await appClient.connect();
  await runMigrations(appClient);
  console.log("Đã tạo database bangbang, user riêng và toàn bộ bảng ban đầu.");
  console.log("File .env đã được tạo; không gửi file này cho người khác.");
} finally {
  await appClient.end().catch(() => {});
}
