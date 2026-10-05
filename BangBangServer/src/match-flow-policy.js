export function summarizeMatchParticipants(participants) {
  return {
    requiredCount: participants.length,
    confirmedCount: participants.filter(
      (participant) => participant.confirmed === true,
    ).length,
    deployedCount: participants.filter(
      (participant) => participant.deployed === true,
    ).length,
    loadedCount: participants.filter(
      (participant) => (
        participant.load_ready === true
        && Number(participant.load_progress) === 100
      ),
    ).length,
  };
}

export function phaseIsComplete(participants, field) {
  const summary = summarizeMatchParticipants(participants);
  if (summary.requiredCount === 0) {
    return false;
  }
  if (field === "confirmed") {
    return summary.confirmedCount === summary.requiredCount;
  }
  if (field === "deployed") {
    return summary.deployedCount === summary.requiredCount;
  }
  if (field === "loaded") {
    return summary.loadedCount === summary.requiredCount;
  }
  return false;
}
