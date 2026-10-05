import { access, readdir } from "node:fs/promises";
import { constants } from "node:fs";
import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

async function executableExists(filePath) {
  try {
    await access(filePath, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

export async function resolvePostgresTool(name) {
  const executable = process.platform === "win32" ? `${name}.exe` : name;
  if (process.env.POSTGRES_BIN) {
    const candidate = path.join(process.env.POSTGRES_BIN, executable);
    if (await executableExists(candidate)) {
      return candidate;
    }
  }
  if (process.platform === "win32") {
    const root = process.env.ProgramFiles
      ? path.join(process.env.ProgramFiles, "PostgreSQL")
      : "C:\\Program Files\\PostgreSQL";
    try {
      const versions = (await readdir(root)).sort().reverse();
      for (const version of versions) {
        const candidate = path.join(root, version, "bin", executable);
        if (await executableExists(candidate)) {
          return candidate;
        }
      }
    } catch {
      // Fall through to PATH.
    }
  }
  return executable;
}

export function postgresCliConnection(databaseUrl, databaseName = null) {
  const parsed = new URL(databaseUrl);
  if (!new Set(["postgres:", "postgresql:"]).has(parsed.protocol)) {
    throw new Error("DATABASE_URL must use postgresql:// or postgres://.");
  }
  const selectedDatabase = databaseName ?? decodeURIComponent(parsed.pathname.slice(1));
  if (!selectedDatabase) {
    throw new Error("DATABASE_URL must contain a database name.");
  }
  return {
    args: [
      "--host", parsed.hostname,
      "--port", parsed.port || "5432",
      "--username", decodeURIComponent(parsed.username),
      "--dbname", selectedDatabase,
    ],
    env: {
      ...process.env,
      PGPASSWORD: decodeURIComponent(parsed.password),
      PGSSLMODE: parsed.searchParams.get("sslmode") ?? process.env.PGSSLMODE ?? "prefer",
    },
  };
}

export async function runPostgresTool(name, args, options = {}) {
  const executable = path.isAbsolute(name) ? name : await resolvePostgresTool(name);
  return execFileAsync(executable, args, {
    env: options.env ?? process.env,
    cwd: options.cwd,
    maxBuffer: 8 * 1024 * 1024,
    windowsHide: true,
  });
}
