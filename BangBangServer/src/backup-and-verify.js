import { execFile } from "node:child_process";
import path from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
const outputDirectory = process.argv[2] || "backups";
const nodeArgs = ["--env-file-if-exists=.env"];
const backup = await execFileAsync(
  process.execPath,
  [...nodeArgs, "src/backup-database.js", outputDirectory],
  { cwd: process.cwd(), windowsHide: true },
);
process.stdout.write(backup.stdout);
const match = backup.stdout.match(/DATABASE_BACKUP_OK (.+\.dump)\s*$/m);
if (!match) {
  throw new Error("Backup command did not return an archive path.");
}
const archivePath = path.resolve(match[1].trim());
const verify = await execFileAsync(
  process.execPath,
  [...nodeArgs, "src/verify-database-backup.js", archivePath],
  { cwd: process.cwd(), windowsHide: true },
);
process.stdout.write(verify.stdout);
console.log(`DATABASE_BACKUP_AND_RESTORE_OK ${archivePath}`);
