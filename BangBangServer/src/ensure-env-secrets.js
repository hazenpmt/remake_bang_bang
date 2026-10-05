import { randomBytes } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";

const envUrl = new URL("../.env", import.meta.url);
let content = await readFile(envUrl, "utf8");

function appendSecret(name) {
  if (new RegExp(`^${name}=.+$`, "m").test(content)) {
    return false;
  }
  if (!content.endsWith("\n")) {
    content += "\n";
  }
  content += `${name}=${randomBytes(32).toString("base64url")}\n`;
  return true;
}

const generated = [];
if (appendSecret("REGISTRATION_HASH_SECRET")) {
  generated.push("REGISTRATION_HASH_SECRET");
}
if (appendSecret("RATE_LIMIT_KEY_SECRET")) {
  generated.push("RATE_LIMIT_KEY_SECRET");
}
if (/^METRICS_ENABLED=(true|1)$/mi.test(content) && appendSecret("METRICS_BEARER_TOKEN")) {
  generated.push("METRICS_BEARER_TOKEN");
}
if (generated.length > 0) {
  await writeFile(envUrl, content, "utf8");
  console.log(`Generated ${generated.join(", ")} in .env.`);
}
