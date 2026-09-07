export type Schedule =
  | { kind: "once"; startAt: string }
  | { kind: "interval"; startAt: string; everySeconds: number; count?: number; until?: string };

const MAX_DATE = Date.parse("9999-12-31T23:59:59.999Z");

export function utcTimestamp(value: unknown): number {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)) {
    throw new Error("Use a UTC timestamp such as 2026-09-07T09:00:00.000Z");
  }
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp) || new Date(timestamp).toISOString() !== value) {
    throw new Error("Invalid UTC date");
  }
  return timestamp;
}

export function parseSchedule(value: unknown): Schedule {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("Invalid schedule");
  const data = value as Record<string, unknown>;
  const start = utcTimestamp(data.startAt);
  if (data.kind === "once") {
    if (Object.keys(data).some((key) => !["kind", "startAt"].includes(key))) throw new Error("Unknown schedule field");
    return { kind: "once", startAt: data.startAt as string };
  }
  if (data.kind !== "interval") throw new Error("Only once and elapsed-time interval schedules are implemented");
  if (Object.keys(data).some((key) => !["kind", "startAt", "everySeconds", "count", "until"].includes(key))) {
    throw new Error("Unknown schedule field");
  }
  if (!Number.isInteger(data.everySeconds) || (data.everySeconds as number) < 60 || (data.everySeconds as number) > 31536000) {
    throw new Error("everySeconds must be an integer between 60 and 31536000");
  }
  if (data.count !== undefined && (!Number.isInteger(data.count) || (data.count as number) < 1 || (data.count as number) > 10000)) {
    throw new Error("count must be an integer between 1 and 10000");
  }
  if (data.until !== undefined && utcTimestamp(data.until) < start) throw new Error("until cannot precede startAt");
  if (data.count !== undefined && data.until !== undefined) throw new Error("Choose count or until, not both");
  return {
    kind: "interval", startAt: data.startAt as string, everySeconds: data.everySeconds as number,
    ...(data.count !== undefined ? { count: data.count as number } : {}),
    ...(data.until !== undefined ? { until: data.until as string } : {}),
  };
}

/** after is exclusive; count includes the original start, not just returned results. */
export function nextOccurrences(input: unknown, after: string, limit = 10): string[] {
  const schedule = parseSchedule(input);
  const cursor = utcTimestamp(after);
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) throw new Error("limit must be between 1 and 100");
  const start = utcTimestamp(schedule.startAt);
  if (schedule.kind === "once") return start > cursor ? [schedule.startAt] : [];
  const step = schedule.everySeconds * 1000;
  const end = schedule.until ? utcTimestamp(schedule.until) : MAX_DATE;
  // Jump directly to the next occurrence; never iterate through an offline backlog.
  const first = Math.max(0, Math.floor((cursor - start) / step) + 1);
  const result: string[] = [];
  for (let index = first; result.length < limit && index < (schedule.count ?? Infinity); index++) {
    const time = start + index * step;
    if (time > end || time > MAX_DATE) break;
    result.push(new Date(time).toISOString());
  }
  return result;
}
