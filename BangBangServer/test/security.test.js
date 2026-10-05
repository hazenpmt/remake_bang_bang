import assert from "node:assert/strict";
import test from "node:test";
import {
  createSessionToken,
  hashPassword,
  hashSessionToken,
  verifyPassword,
} from "../src/security.js";
import {
  validateChatMessage,
  validateCharacter,
  validateCredentials,
  validateLoginCredentials,
} from "../src/validation.js";

test("password hash can be verified", async () => {
  const hash = await hashPassword("matkhau123");
  assert.equal(await verifyPassword("matkhau123", hash), true);
  assert.equal(await verifyPassword("sai-mat-khau", hash), false);
  assert.equal(hash.includes("matkhau123"), false);
});

test("session tokens are random and only hashes are stored", () => {
  const first = createSessionToken();
  const second = createSessionToken();
  assert.notEqual(first, second);
  assert.equal(hashSessionToken(first).length, 64);
});

test("credential and character validation", () => {
  assert.equal(
    validateCredentials({ username: "Player_01", password: "12345678" }).ok,
    true,
  );
  assert.equal(
    validateCredentials({ username: "player", password: "123456" }).ok,
    true,
  );
  assert.equal(
    validateCredentials({ username: "a", password: "123" }).ok,
    false,
  );
  assert.equal(
    validateLoginCredentials({ username: "admin", password: "123456" }).ok,
    true,
  );
  assert.equal(
    validateCredentials({ username: "admin", password: "123456" }).ok,
    false,
  );
  assert.equal(
    validateLoginCredentials({ username: "root", password: "123456" }).ok,
    false,
  );
  assert.equal(
    validateCredentials({
      username: "tai_khoan_qua_dai",
      password: "mat_khau_cung_qua_dai",
    }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "Ngộ Không", gender: "male" }).ok,
    true,
  );
  assert.equal(
    validateCharacter({ display_name: "Tèo123", gender: "male" }).ok,
    true,
  );
  assert.equal(
    validateCharacter({ display_name: "ab", gender: "male" }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "TênQuáMườiKýTự", gender: "female" }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "Ngộ  Không", gender: "male" }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "Ngộ_Không", gender: "male" }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "12345", gender: "male" }).ok,
    false,
  );
  assert.equal(
    validateCharacter({ display_name: "Admin", gender: "male" }).ok,
    false,
  );
  assert.equal(
    validateCharacter(
      { display_name: "Admin", gender: "male" },
      { allowAdminName: true },
    ).ok,
    true,
  );
  assert.equal(
    validateCharacter(
      { display_name: "GM", gender: "male" },
      { allowAdminName: true },
    ).ok,
    false,
  );
});

test("world chat message validation", () => {
  assert.deepEqual(validateChatMessage({ message: "  Xin   chào!  " }), {
    ok: true,
    message: "Xin chào!",
  });
  assert.equal(validateChatMessage({ message: "   " }).ok, false);
  assert.equal(validateChatMessage({ message: "a".repeat(121) }).ok, false);
  assert.equal(validateChatMessage({ message: "a".repeat(120) }).ok, true);
});

test("battle chat can enforce its two-line bubble limit", () => {
  assert.equal(validateChatMessage({ message: "a".repeat(65) }, 64).ok, false);
  assert.equal(validateChatMessage({ message: "a".repeat(64) }, 64).ok, true);
});
