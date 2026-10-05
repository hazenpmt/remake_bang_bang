import assert from "node:assert/strict";
import test from "node:test";

import { compactRoomMembers } from "../src/room-member-order.js";

test("room members occupy five slots in join order", () => {
  const members = compactRoomMembers([
    { account_id: 5, join_order: "50" },
    { account_id: 2, join_order: "20" },
    { account_id: 1, join_order: "10" },
    { account_id: 4, join_order: "40" },
    { account_id: 3, join_order: "30" },
  ]);

  assert.deepEqual(
    members.map((member) => [
      member.account_id,
      member.slot,
      member.is_captain,
    ]),
    [
      [1, 1, true],
      [2, 2, false],
      [3, 3, false],
      [4, 4, false],
      [5, 5, false],
    ],
  );
});

test("next joined member is promoted and all later members shift after captain leaves", () => {
  const remainingMembers = [
    { account_id: 2, join_order: "20" },
    { account_id: 3, join_order: "30" },
    { account_id: 4, join_order: "40" },
    { account_id: 5, join_order: "50" },
  ];

  const promoted = compactRoomMembers(remainingMembers);

  assert.deepEqual(
    promoted.map((member) => [
      member.account_id,
      member.slot,
      member.is_captain,
    ]),
    [
      [2, 1, true],
      [3, 2, false],
      [4, 3, false],
      [5, 4, false],
    ],
  );
});
