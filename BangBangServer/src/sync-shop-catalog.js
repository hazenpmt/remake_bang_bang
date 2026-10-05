import path from "node:path";
import { fileURLToPath } from "node:url";
import { withTransaction, pool } from "./db.js";
import { loadCatalogDirectory, publishCatalog } from "./shop-catalog.js";

const serverRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const defaultRoot = path.resolve(serverRoot, "../BangBangRemake/shop_content");
const catalogRoot = path.resolve(process.argv[2] ?? process.env.SHOP_CATALOG_DIR ?? defaultRoot);

try {
  const catalog = await loadCatalogDirectory(catalogRoot);
  const result = await withTransaction((client) => publishCatalog(client, catalog));
  console.log(
    `${result.changed ? "Đã publish" : "Catalog không đổi"}: ` +
    `${catalog.items.length} item, ${catalog.offers.length} offer, ` +
    `${catalog.shelves.length} shelf, revision ${result.revision}.`,
  );
} finally {
  await pool.end();
}
