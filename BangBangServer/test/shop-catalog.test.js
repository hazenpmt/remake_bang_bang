import assert from "node:assert/strict";
import test from "node:test";
import {
  CatalogValidationError,
  catalogContentHash,
  validateCatalog,
} from "../src/shop-catalog.js";

function sampleCatalog(overrides = {}) {
  return {
    shelves: [{ shelf_id: "recommend", label: "ĐỀ CỬ", layout: "small" }],
    items: [{
      item_id: "chip_1",
      item_type: "material",
      name: "Chip",
      description: "",
      image: "res://chip.png",
    }],
    offers: [{
      offer_id: "offer_chip_1",
      item_id: "chip_1",
      shelf_ids: ["recommend"],
      currency: "silver",
      price: 100,
    }],
    ...overrides,
  };
}

test("catalog separates item, offer and shelf and derives safe stack grant", () => {
  const catalog = validateCatalog(sampleCatalog());
  assert.deepEqual(catalog.items[0].grant, { kind: "inventory_stack" });
  assert.equal(catalog.offers[0].price, 100);
  assert.deepEqual(catalog.offers[0].shelf_ids, ["recommend"]);
  assert.equal(catalog.schema_version, 2);
});

test("gameplay items require an explicit server grant mapping", () => {
  assert.throws(
    () => validateCatalog(sampleCatalog({
      items: [{
        item_id: "iron_man",
        item_type: "tank",
        name: "Iron Man",
        image: "res://iron-man.png",
      }],
      offers: [{
        offer_id: "offer_iron_man",
        item_id: "iron_man",
        shelf_ids: ["recommend"],
        currency: "locked_xu",
        price: 2000,
      }],
    })),
    CatalogValidationError,
  );
});

test("catalog rejects dangling shelves and invalid discount prices", () => {
  assert.throws(
    () => validateCatalog(sampleCatalog({
      offers: [{
        offer_id: "offer_chip_1",
        item_id: "chip_1",
        shelf_ids: ["missing"],
        currency: "silver",
        price: 100,
      }],
    })),
    /shelf không tồn tại/,
  );
  assert.throws(
    () => validateCatalog(sampleCatalog({
      offers: [{
        offer_id: "offer_chip_1",
        item_id: "chip_1",
        shelf_ids: ["recommend"],
        currency: "silver",
        price: 100,
        original_price: 50,
      }],
    })),
    /original_price/,
  );
});

test("catalog hash is stable across object key order", () => {
  const first = catalogContentHash({ a: 1, nested: { b: 2, a: 1 } });
  const second = catalogContentHash({ nested: { a: 1, b: 2 }, a: 1 });
  assert.equal(first, second);
  assert.equal(first.length, 64);
});

test("validated catalog remains stable when a saved draft is validated again", () => {
  const first = validateCatalog(sampleCatalog({
    items: [{
      item_id: "chip_1",
      item_type: "material",
      name: "Chip",
      description: "",
      image: "content://chip_image",
      fallback_image: "res://chip.png",
      skills: ["content://chip_skill"],
    }],
  }));
  const second = validateCatalog(first);
  assert.deepEqual(second, first);
  assert.deepEqual(second.items[0].presentation, {
    fallback_image: "res://chip.png",
    skills: ["content://chip_skill"],
  });
});
