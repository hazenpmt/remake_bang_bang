import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("PvP team chat derives the channel from the authenticated match participant", async () => {
  const gameRoomsSource = await readFile(
    new URL("../src/game-rooms.js", import.meta.url),
    "utf8",
  );
  const serverSource = await readFile(
    new URL("../src/server.js", import.meta.url),
    "utf8",
  );

  assert.match(
    gameRoomsSource,
    /AND message\.team_no = \$2/,
    "message reads must filter by the viewer's resolved team",
  );
  assert.match(
    gameRoomsSource,
    /FROM game_match_battle_messages message[\s\S]*?WHERE message\.match_id = \$1[\s\S]*?AND message\.id > \$2::bigint/,
    "battle messages must be shared by match without a team-number filter",
  );
  assert.match(
    gameRoomsSource,
    /\[context\.match_id, context\.team_no, accountId, message\]/,
    "message writes must use the server-resolved match and team",
  );
  assert.match(
    serverSource,
    /sendGameMatchTeamMessage\(account\.id, input\.message\)/,
    "the API must not accept a client-supplied team number",
  );
  assert.match(
    serverSource,
    /validateChatMessage\(body, BATTLE_CHAT_MESSAGE_MAX_LENGTH\)/,
    "match chat must enforce the 64-character transport safety limit",
  );
  assert.doesNotMatch(
    serverSource,
    /sendGameMatchTeamMessage\([^)]*body\?\.team/u,
  );
});

test("PvP match chat stays scoped to an active match and exposes connection state", async () => {
  const gameRoomsSource = await readFile(
    new URL("../src/game-rooms.js", import.meta.url),
    "utf8",
  );

  assert.match(
    gameRoomsSource,
    /\["selecting", "loading", "transition", "active"\]\.includes\(context\.phase\)/,
    "match chat must remain available while the battle phase is active",
  );
  assert.match(
    gameRoomsSource,
    /context\.phase === "finished"[\s\S]*?2 \* 60 \* 1000/,
    "result chat must stay open briefly without exposing an old match forever",
  );
  assert.match(
    gameRoomsSource,
    /participant\.updated_at AS battle_joined_at/,
    "the client needs the authoritative loading order for join messages",
  );
  assert.match(
    gameRoomsSource,
    /live_presence\.lease_expires_at > NOW\(\)/,
    "network/AFK departures must use the server presence lease",
  );
  assert.match(
    gameRoomsSource,
    /live_matchmaking\.match_id = participant\.match_id/,
    "explicit room departure must be reflected in the participant connection state",
  );
});
