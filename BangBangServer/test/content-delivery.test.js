import assert from "node:assert/strict";
import test from "node:test";

process.env.REGISTRATION_HASH_SECRET = "content-test-registration-secret-long-enough";
process.env.RATE_LIMIT_KEY_SECRET = "content-test-rate-limit-secret-long-enough";
const { contentAssetIds, materializeManifest } = await import(
  "../src/content-delivery.js"
);

test("content manifest finds immutable URIs in image and presentation skills", () => {
  assert.deepEqual(contentAssetIds({
    items: [
      { image: "content://tank_image", presentation: { skills: ["content://skill_1"] } },
      { image: "res://base.png", skills: ["content://skill_1", "content://skill_2"] },
    ],
  }), ["skill_1", "skill_2", "tank_image"]);
});

test("content manifest materializes local and CDN URLs without changing hashes", () => {
  const manifest = materializeManifest({
    assets: [{ asset_id: "egg", sha256: "a".repeat(64), storage_key: "images/a.png" }],
  }, "https://cdn.example/");
  assert.equal(manifest.assets[0].url, "https://cdn.example/content/images/a.png");
  assert.equal(manifest.assets[0].sha256, "a".repeat(64));
});
