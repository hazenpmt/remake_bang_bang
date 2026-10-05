import { createHash } from "node:crypto";

const IDEMPOTENCY_KEY_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const ID_PATTERN = /^[a-z0-9_]{1,64}$/;
const CURRENCY_COLUMNS = Object.freeze({
  xu: "xu",
  locked_xu: "locked_xu",
  silver: "silver",
});
const MAX_BIGINT = 9_223_372_036_854_775_807n;

export class EconomyError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function error(status, code, message) {
  throw new EconomyError(status, code, message);
}

function numberFromDatabase(value) {
  const result = Number(value ?? 0);
  if (!Number.isSafeInteger(result)) {
    error(500, "ECONOMY_VALUE_OUT_OF_RANGE", "Dữ liệu kinh tế vượt giới hạn an toàn.");
  }
  return result;
}

function normalizedJson(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {};
}

export function validatePurchaseRequest(body, idempotencyKey) {
  const offerId = String(body?.offer_id ?? "").trim();
  const quantity = body?.quantity ?? 1;
  const key = String(idempotencyKey ?? "").trim();
  if (!ID_PATTERN.test(offerId)) {
    error(400, "INVALID_OFFER", "Offer không hợp lệ.");
  }
  if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 999) {
    error(400, "INVALID_QUANTITY", "Số lượng mua phải từ 1 đến 999.");
  }
  if (!IDEMPOTENCY_KEY_PATTERN.test(key)) {
    error(
      400,
      "IDEMPOTENCY_KEY_REQUIRED",
      "Giao dịch phải có Idempotency-Key hợp lệ để chống mua lặp.",
    );
  }
  return { offerId, quantity, idempotencyKey: key };
}

export function purchaseRequestHash(offerId, quantity) {
  return createHash("sha256")
    .update(JSON.stringify({ offer_id: offerId, quantity }))
    .digest("hex");
}

function itemFromRow(row) {
  return {
    item_id: row.item_id,
    item_type: row.item_type,
    name: row.display_name,
    description: row.description,
    image: row.image_asset_key,
    ...normalizedJson(row.presentation),
    owned: Number(row.owned_quantity ?? 0) > 0,
    owned_quantity: numberFromDatabase(row.owned_quantity),
  };
}

async function loadOwnedItemRows(client, accountId, onlyOwned = false) {
  return client.query(
    `SELECT item.item_id, item.item_type, item.display_name,
            item.description, item.image_asset_key, item.presentation,
            CASE item.grant_spec->>'kind'
              WHEN 'inventory_stack' THEN COALESCE(stack.quantity, 0)
              WHEN 'inventory_unique' THEN COALESCE(stack.quantity, 0)
              WHEN 'tank' THEN CASE WHEN EXISTS (
                SELECT 1
                  FROM player_tanks owned_tank
                  JOIN tanks tank ON tank.id = owned_tank.tank_id
                 WHERE owned_tank.account_id = $1
                   AND tank.tank_key = item.grant_spec->>'tank_key'
              ) THEN 1 ELSE 0 END
              WHEN 'tank_skin' THEN CASE WHEN EXISTS (
                SELECT 1
                  FROM player_tank_skins owned_skin
                  JOIN tank_skins skin ON skin.id = owned_skin.tank_skin_id
                  JOIN tanks tank ON tank.id = skin.tank_id
                 WHERE owned_skin.account_id = $1
                   AND tank.tank_key = item.grant_spec->>'tank_key'
                   AND skin.skin_key = item.grant_spec->>'skin_key'
              ) THEN 1 ELSE 0 END
              WHEN 'vip' THEN CASE WHEN EXISTS (
                SELECT 1
                  FROM player_entitlements entitlement
                 WHERE entitlement.account_id = $1
                   AND entitlement.entitlement_key = 'vip'
                   AND entitlement.expires_at > NOW()
              ) THEN 1 ELSE 0 END
              ELSE 0
            END::bigint AS owned_quantity
       FROM item_definitions item
       LEFT JOIN inventory_stacks stack
         ON stack.account_id = $1 AND stack.item_id = item.item_id
      WHERE item.enabled
        AND ($2::boolean = FALSE OR
          CASE item.grant_spec->>'kind'
            WHEN 'inventory_stack' THEN COALESCE(stack.quantity, 0) > 0
            WHEN 'inventory_unique' THEN COALESCE(stack.quantity, 0) > 0
            WHEN 'tank' THEN EXISTS (
              SELECT 1 FROM player_tanks owned_tank
              JOIN tanks tank ON tank.id = owned_tank.tank_id
              WHERE owned_tank.account_id = $1
                AND tank.tank_key = item.grant_spec->>'tank_key'
            )
            WHEN 'tank_skin' THEN EXISTS (
              SELECT 1 FROM player_tank_skins owned_skin
              JOIN tank_skins skin ON skin.id = owned_skin.tank_skin_id
              JOIN tanks tank ON tank.id = skin.tank_id
              WHERE owned_skin.account_id = $1
                AND tank.tank_key = item.grant_spec->>'tank_key'
                AND skin.skin_key = item.grant_spec->>'skin_key'
            )
            WHEN 'vip' THEN EXISTS (
              SELECT 1 FROM player_entitlements entitlement
              WHERE entitlement.account_id = $1
                AND entitlement.entitlement_key = 'vip'
                AND entitlement.expires_at > NOW()
            )
            ELSE FALSE
          END)
      ORDER BY item.item_type, item.item_id`,
    [accountId, onlyOwned],
  );
}

async function loadBalances(client, accountId, lock = false) {
  const result = await client.query(
    `SELECT xu, locked_xu, silver
       FROM player_currencies
      WHERE account_id = $1${lock ? " FOR UPDATE" : ""}`,
    [accountId],
  );
  if (result.rowCount !== 1) {
    error(409, "CHARACTER_REQUIRED", "Tài khoản chưa có nhân vật.");
  }
  return {
    xu: numberFromDatabase(result.rows[0].xu),
    locked_xu: numberFromDatabase(result.rows[0].locked_xu),
    silver: numberFromDatabase(result.rows[0].silver),
  };
}

export async function loadShopCatalog(client, accountId) {
  const [state, shelves, items, offers, balances] = await Promise.all([
    client.query(
      `SELECT revision, published_at
         FROM shop_catalog_state
        WHERE singleton`,
    ),
    client.query(
      `SELECT shelf_id, label, layout
         FROM shop_shelves
        WHERE enabled
        ORDER BY sort_order, shelf_id`,
    ),
    loadOwnedItemRows(client, accountId),
    client.query(
      `SELECT offer.offer_id, offer.item_id, offer.currency, offer.price,
              offer.original_price, offer.badges, offer.starts_at, offer.ends_at,
              offer.purchase_limit, offer.max_quantity_per_order,
              offer.giftable, offer.preview_enabled, offer.sort_priority,
              offer.required_level, offer.required_vip,
              COALESCE(counter.purchased_quantity, 0) AS purchased_quantity,
              array_agg(link.shelf_id ORDER BY shelf.sort_order, link.shelf_id)
                AS shelf_ids
         FROM shop_offers offer
         JOIN item_definitions item
           ON item.item_id = offer.item_id AND item.enabled
         JOIN shop_offer_shelves link ON link.offer_id = offer.offer_id
         JOIN shop_shelves shelf
           ON shelf.shelf_id = link.shelf_id AND shelf.enabled
         LEFT JOIN shop_purchase_counters counter
           ON counter.account_id = $1 AND counter.offer_id = offer.offer_id
        WHERE offer.enabled
          AND (offer.starts_at IS NULL OR offer.starts_at <= NOW())
          AND (offer.ends_at IS NULL OR offer.ends_at > NOW())
        GROUP BY offer.offer_id, counter.purchased_quantity
        ORDER BY offer.sort_priority DESC, offer.offer_id`,
      [accountId],
    ),
    loadBalances(client, accountId),
  ]);

  return {
    schema_version: 2,
    revision: numberFromDatabase(state.rows[0]?.revision),
    server_time: new Date().toISOString(),
    published_at: state.rows[0]?.published_at ?? null,
    balances,
    shelves: shelves.rows,
    items: items.rows.map(itemFromRow),
    offers: offers.rows.map((row) => {
      const purchasedQuantity = numberFromDatabase(row.purchased_quantity);
      const purchaseLimit = row.purchase_limit == null
        ? null
        : numberFromDatabase(row.purchase_limit);
      return {
        offer_id: row.offer_id,
        item_id: row.item_id,
        shelf_ids: row.shelf_ids,
        currency: row.currency,
        price: numberFromDatabase(row.price),
        original_price: row.original_price == null
          ? null
          : numberFromDatabase(row.original_price),
        badges: row.badges,
        start_at: row.starts_at,
        end_at: row.ends_at,
        purchase_limit: purchaseLimit,
        max_quantity_per_order: row.max_quantity_per_order,
        giftable: row.giftable,
        preview_enabled: row.preview_enabled,
        sort_priority: row.sort_priority,
        required_level: row.required_level,
        required_vip: row.required_vip,
        purchased_quantity: purchasedQuantity,
        remaining_limit: purchaseLimit == null
          ? null
          : Math.max(0, purchaseLimit - purchasedQuantity),
      };
    }),
  };
}

export async function loadInventory(client, accountId) {
  const [items, balances, entitlements] = await Promise.all([
    loadOwnedItemRows(client, accountId, true),
    loadBalances(client, accountId),
    client.query(
      `SELECT entitlement_key, expires_at
         FROM player_entitlements
        WHERE account_id = $1 AND expires_at > NOW()
        ORDER BY entitlement_key`,
      [accountId],
    ),
  ]);
  return {
    balances,
    items: items.rows.map(itemFromRow),
    entitlements: entitlements.rows,
  };
}

function assertOfferAvailable(row, quantity) {
  if (!row || !row.offer_enabled || !row.item_enabled) {
    error(404, "OFFER_NOT_FOUND", "Offer không tồn tại hoặc đã bị tắt.");
  }
  const now = Date.now();
  if (row.starts_at && new Date(row.starts_at).getTime() > now) {
    error(409, "OFFER_NOT_STARTED", "Offer chưa bắt đầu bán.");
  }
  if (row.ends_at && new Date(row.ends_at).getTime() <= now) {
    error(409, "OFFER_EXPIRED", "Offer đã hết hạn.");
  }
  if (quantity > Number(row.max_quantity_per_order)) {
    error(409, "ORDER_QUANTITY_LIMIT", "Số lượng vượt giới hạn của một lần mua.");
  }
  if (Number(row.player_level) < Number(row.required_level)) {
    error(403, "LEVEL_REQUIRED", `Cần đạt cấp ${row.required_level} để mua.`);
  }
  if (row.required_vip && !row.has_vip) {
    error(403, "VIP_REQUIRED", "Offer này chỉ dành cho người chơi VIP.");
  }
}

async function grantInventory(client, accountId, itemId, quantity, unique) {
  if (unique && quantity !== 1) {
    error(409, "UNIQUE_ITEM_QUANTITY", "Vật phẩm sở hữu vĩnh viễn chỉ mua từng món.");
  }
  const result = unique
    ? await client.query(
      `INSERT INTO inventory_stacks (account_id, item_id, quantity)
       VALUES ($1, $2, 1)
       ON CONFLICT (account_id, item_id) DO NOTHING
       RETURNING quantity`,
      [accountId, itemId],
    )
    : await client.query(
      `INSERT INTO inventory_stacks (account_id, item_id, quantity)
       VALUES ($1, $2, $3)
       ON CONFLICT (account_id, item_id) DO UPDATE
       SET quantity = inventory_stacks.quantity + EXCLUDED.quantity,
           updated_at = NOW()
       RETURNING quantity`,
      [accountId, itemId, quantity],
    );
  if (result.rowCount !== 1) {
    error(409, "ITEM_ALREADY_OWNED", "Bạn đã sở hữu vật phẩm này.");
  }
  return {
    assetKind: "item",
    assetKey: itemId,
    delta: quantity,
    balanceAfter: numberFromDatabase(result.rows[0].quantity),
  };
}

async function grantTank(client, accountId, itemId, grant, quantity) {
  if (quantity !== 1) {
    error(409, "UNIQUE_ITEM_QUANTITY", "Tank chỉ mua từng chiếc.");
  }
  const inserted = await client.query(
    `INSERT INTO player_tanks (account_id, tank_id, level, experience, is_primary)
     SELECT $1, tank.id, 1, 0,
            NOT EXISTS (
              SELECT 1 FROM player_tanks current
               WHERE current.account_id = $1 AND current.is_primary
            )
       FROM tanks tank
      WHERE tank.tank_key = $2 AND tank.enabled
     ON CONFLICT (account_id, tank_id) DO NOTHING
     RETURNING id, tank_id`,
    [accountId, grant.tank_key],
  );
  if (inserted.rowCount !== 1) {
    const exists = await client.query(
      "SELECT 1 FROM tanks WHERE tank_key = $1 AND enabled",
      [grant.tank_key],
    );
    if (exists.rowCount !== 1) {
      error(500, "ITEM_GRANT_NOT_CONFIGURED", "Tank trong offer chưa được cấu hình.");
    }
    error(409, "ITEM_ALREADY_OWNED", "Bạn đã sở hữu Tank này.");
  }
  await client.query(
    `INSERT INTO player_tank_skins (account_id, tank_skin_id)
     SELECT $1, skin.id
       FROM tank_skins skin
      WHERE skin.tank_id = $2 AND skin.is_default AND skin.enabled
     ON CONFLICT (account_id, tank_skin_id) DO NOTHING`,
    [accountId, inserted.rows[0].tank_id],
  );
  await client.query(
    `UPDATE player_tanks owned
        SET equipped_skin_id = skin.id
       FROM tank_skins skin
      WHERE owned.id = $1
        AND skin.tank_id = owned.tank_id
        AND skin.is_default
        AND skin.enabled
        AND owned.equipped_skin_id IS NULL`,
    [inserted.rows[0].id],
  );
  return { assetKind: "item", assetKey: itemId, delta: 1, balanceAfter: 1 };
}

async function grantTankSkin(client, accountId, itemId, grant, quantity) {
  if (quantity !== 1) {
    error(409, "UNIQUE_ITEM_QUANTITY", "Skin Tank chỉ mua từng bộ.");
  }
  const ownedTank = await client.query(
    `SELECT tank.id
       FROM player_tanks owned
       JOIN tanks tank ON tank.id = owned.tank_id
      WHERE owned.account_id = $1 AND tank.tank_key = $2 AND tank.enabled
      FOR UPDATE OF owned`,
    [accountId, grant.tank_key],
  );
  if (ownedTank.rowCount !== 1) {
    error(409, "TANK_REQUIRED", "Bạn phải sở hữu Tank tương ứng trước khi mua Skin.");
  }
  const inserted = await client.query(
    `INSERT INTO player_tank_skins (account_id, tank_skin_id)
     SELECT $1, skin.id
       FROM tank_skins skin
      WHERE skin.tank_id = $2 AND skin.skin_key = $3 AND skin.enabled
     ON CONFLICT (account_id, tank_skin_id) DO NOTHING
     RETURNING tank_skin_id`,
    [accountId, ownedTank.rows[0].id, grant.skin_key],
  );
  if (inserted.rowCount !== 1) {
    const exists = await client.query(
      `SELECT 1 FROM tank_skins
        WHERE tank_id = $1 AND skin_key = $2 AND enabled`,
      [ownedTank.rows[0].id, grant.skin_key],
    );
    if (exists.rowCount !== 1) {
      error(500, "ITEM_GRANT_NOT_CONFIGURED", "Skin trong offer chưa được cấu hình.");
    }
    error(409, "ITEM_ALREADY_OWNED", "Bạn đã sở hữu Skin này.");
  }
  return { assetKind: "item", assetKey: itemId, delta: 1, balanceAfter: 1 };
}

async function grantVip(client, accountId, itemId, grant, quantity) {
  const durationDays = Number(grant.duration_days);
  if (!Number.isSafeInteger(durationDays) || durationDays < 1 || durationDays > 3650) {
    error(500, "ITEM_GRANT_NOT_CONFIGURED", "Thời hạn VIP chưa được cấu hình đúng.");
  }
  const addedDays = durationDays * quantity;
  if (!Number.isSafeInteger(addedDays) || addedDays > 36500) {
    error(409, "ENTITLEMENT_LIMIT", "Thời hạn VIP của giao dịch quá lớn.");
  }
  const result = await client.query(
    `INSERT INTO player_entitlements
       (account_id, entitlement_key, expires_at)
     VALUES ($1, 'vip', NOW() + ($2 * INTERVAL '1 day'))
     ON CONFLICT (account_id, entitlement_key) DO UPDATE
     SET expires_at = GREATEST(player_entitlements.expires_at, NOW())
                      + ($2 * INTERVAL '1 day'),
         updated_at = NOW()
     RETURNING expires_at,
       CEIL(EXTRACT(EPOCH FROM (expires_at - NOW())) / 86400)::bigint AS days_remaining`,
    [accountId, addedDays],
  );
  return {
    assetKind: "entitlement",
    assetKey: "vip",
    delta: addedDays,
    balanceAfter: numberFromDatabase(result.rows[0].days_remaining),
    entitlementExpiresAt: result.rows[0].expires_at,
    purchasedItemId: itemId,
  };
}

async function grantItem(client, accountId, row, quantity) {
  const grant = normalizedJson(row.grant_spec);
  if (grant.kind === "inventory_stack") {
    return grantInventory(client, accountId, row.item_id, quantity, false);
  }
  if (grant.kind === "inventory_unique") {
    return grantInventory(client, accountId, row.item_id, quantity, true);
  }
  if (grant.kind === "tank") {
    return grantTank(client, accountId, row.item_id, grant, quantity);
  }
  if (grant.kind === "tank_skin") {
    return grantTankSkin(client, accountId, row.item_id, grant, quantity);
  }
  if (grant.kind === "vip") {
    return grantVip(client, accountId, row.item_id, grant, quantity);
  }
  error(500, "ITEM_GRANT_NOT_CONFIGURED", "Vật phẩm chưa có quy tắc cấp trên máy chủ.");
}

export async function purchaseOffer(client, accountId, input) {
  const requestHash = purchaseRequestHash(input.offerId, input.quantity);
  await client.query("SELECT pg_advisory_xact_lock($1::bigint)", [accountId]);

  const previous = await client.query(
    `SELECT request_hash, response_payload
       FROM purchase_orders
      WHERE account_id = $1 AND idempotency_key = $2
      FOR UPDATE`,
    [accountId, input.idempotencyKey],
  );
  if (previous.rowCount === 1) {
    if (previous.rows[0].request_hash !== requestHash) {
      error(
        409,
        "IDEMPOTENCY_CONFLICT",
        "Mã chống mua lặp đã được dùng cho một giao dịch khác.",
      );
    }
    return { ...previous.rows[0].response_payload, idempotent_replay: true };
  }

  const offerResult = await client.query(
    `SELECT offer.offer_id, offer.item_id, offer.currency, offer.price,
            offer.starts_at, offer.ends_at, offer.purchase_limit,
            offer.max_quantity_per_order, offer.required_level,
            offer.required_vip, offer.enabled AS offer_enabled,
            item.enabled AS item_enabled, item.grant_spec,
            profile.level AS player_level,
            EXISTS (
              SELECT 1 FROM player_entitlements entitlement
               WHERE entitlement.account_id = $2
                 AND entitlement.entitlement_key = 'vip'
                 AND entitlement.expires_at > NOW()
            ) AS has_vip
       FROM shop_offers offer
       JOIN item_definitions item ON item.item_id = offer.item_id
       JOIN player_profiles profile ON profile.account_id = $2
      WHERE offer.offer_id = $1
      FOR UPDATE OF offer, item, profile`,
    [input.offerId, accountId],
  );
  const offer = offerResult.rows[0];
  assertOfferAvailable(offer, input.quantity);

  await client.query(
    `INSERT INTO shop_purchase_counters (account_id, offer_id)
     VALUES ($1, $2)
     ON CONFLICT (account_id, offer_id) DO NOTHING`,
    [accountId, input.offerId],
  );
  const counter = await client.query(
    `SELECT purchased_quantity
       FROM shop_purchase_counters
      WHERE account_id = $1 AND offer_id = $2
      FOR UPDATE`,
    [accountId, input.offerId],
  );
  const purchasedBefore = BigInt(counter.rows[0].purchased_quantity);
  if (
    offer.purchase_limit != null &&
    purchasedBefore + BigInt(input.quantity) > BigInt(offer.purchase_limit)
  ) {
    error(409, "PURCHASE_LIMIT_REACHED", "Bạn đã đạt giới hạn mua của offer này.");
  }

  const unitPrice = BigInt(offer.price);
  const totalPrice = unitPrice * BigInt(input.quantity);
  if (totalPrice > MAX_BIGINT) {
    error(409, "PRICE_OUT_OF_RANGE", "Tổng giá trị giao dịch quá lớn.");
  }
  const currencyColumn = CURRENCY_COLUMNS[offer.currency];
  if (!currencyColumn) {
    error(500, "INVALID_SERVER_CURRENCY", "Tiền tệ của offer chưa được cấu hình đúng.");
  }
  const balancesBefore = await loadBalances(client, accountId, true);
  if (BigInt(balancesBefore[offer.currency]) < totalPrice) {
    error(409, "INSUFFICIENT_FUNDS", "Số dư không đủ để mua vật phẩm này.");
  }

  const grant = await grantItem(client, accountId, offer, input.quantity);
  let currencyBalanceAfter = BigInt(balancesBefore[offer.currency]);
  if (totalPrice > 0n) {
    const debit = await client.query(
      `UPDATE player_currencies
          SET ${currencyColumn} = ${currencyColumn} - $2,
              updated_at = NOW()
        WHERE account_id = $1 AND ${currencyColumn} >= $2
        RETURNING ${currencyColumn} AS balance_after`,
      [accountId, totalPrice.toString()],
    );
    if (debit.rowCount !== 1) {
      error(409, "INSUFFICIENT_FUNDS", "Số dư không đủ để mua vật phẩm này.");
    }
    currencyBalanceAfter = BigInt(debit.rows[0].balance_after);
  }

  await client.query(
    `UPDATE shop_purchase_counters
        SET purchased_quantity = purchased_quantity + $3,
            updated_at = NOW()
      WHERE account_id = $1 AND offer_id = $2`,
    [accountId, input.offerId, input.quantity],
  );

  const order = await client.query(
    `INSERT INTO purchase_orders
       (account_id, idempotency_key, request_hash, offer_id, quantity,
        currency, unit_price, total_price, response_payload)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, '{}'::jsonb)
     RETURNING id, created_at`,
    [
      accountId,
      input.idempotencyKey,
      requestHash,
      input.offerId,
      input.quantity,
      offer.currency,
      unitPrice.toString(),
      totalPrice.toString(),
    ],
  );
  const transactionKey = createHash("sha256")
    .update(`${accountId}:${input.idempotencyKey}`)
    .digest("hex");
  let entryIndex = 0;
  if (totalPrice > 0n) {
    await client.query(
      `INSERT INTO economy_ledger
         (account_id, transaction_key, entry_index, asset_kind, asset_key,
          delta, balance_after, reason, reference_type, reference_id, metadata)
       VALUES ($1, $2, $3, 'currency', $4, $5, $6,
               'purchase', 'purchase_order', $7, $8::jsonb)`,
      [
        accountId,
        transactionKey,
        entryIndex++,
        offer.currency,
        (-totalPrice).toString(),
        currencyBalanceAfter.toString(),
        String(order.rows[0].id),
        JSON.stringify({ offer_id: input.offerId }),
      ],
    );
  }
  await client.query(
    `INSERT INTO economy_ledger
       (account_id, transaction_key, entry_index, asset_kind, asset_key,
        delta, balance_after, reason, reference_type, reference_id, metadata)
     VALUES ($1, $2, $3, $4, $5, $6, $7,
             'purchase', 'purchase_order', $8, $9::jsonb)`,
    [
      accountId,
      transactionKey,
      entryIndex,
      grant.assetKind,
      grant.assetKey,
      grant.delta,
      grant.balanceAfter,
      String(order.rows[0].id),
      JSON.stringify({ offer_id: input.offerId, item_id: offer.item_id }),
    ],
  );

  const balances = { ...balancesBefore };
  balances[offer.currency] = numberFromDatabase(currencyBalanceAfter.toString());
  const response = {
    purchase_id: String(order.rows[0].id),
    created_at: order.rows[0].created_at,
    offer_id: input.offerId,
    item_id: offer.item_id,
    quantity: input.quantity,
    currency: offer.currency,
    unit_price: numberFromDatabase(unitPrice.toString()),
    total_price: numberFromDatabase(totalPrice.toString()),
    balances,
    grant: {
      asset_kind: grant.assetKind,
      asset_key: grant.assetKey,
      balance_after: grant.balanceAfter,
      entitlement_expires_at: grant.entitlementExpiresAt ?? null,
    },
    idempotent_replay: false,
  };
  await client.query(
    "UPDATE purchase_orders SET response_payload = $2::jsonb WHERE id = $1",
    [order.rows[0].id, JSON.stringify(response)],
  );
  return response;
}
