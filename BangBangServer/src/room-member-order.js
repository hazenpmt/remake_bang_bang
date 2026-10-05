export function compactRoomMembers(rows) {
  return [...rows]
    .sort((left, right) => {
      const leftOrder = BigInt(left.join_order);
      const rightOrder = BigInt(right.join_order);
      return leftOrder < rightOrder ? -1 : leftOrder > rightOrder ? 1 : 0;
    })
    .map((member, index) => ({
      ...member,
      slot: index + 1,
      is_captain: index === 0,
    }));
}
