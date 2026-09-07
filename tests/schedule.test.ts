import { describe, expect, it } from "vitest";
import { nextOccurrences, parseSchedule, utcTimestamp } from "../apps/api/src/schedule";

const startAt = "2026-09-07T09:00:00.000Z";
const before = "2026-09-07T08:59:59.999Z";
const interval = { kind: "interval", startAt, everySeconds: 3600 };

describe("bounded deterministic elapsed-time scheduling", () => {
  it("returns a once occurrence only strictly after the cursor", () => {
    expect(nextOccurrences({ kind: "once", startAt }, before)).toEqual([startAt]);
    expect(nextOccurrences({ kind: "once", startAt }, startAt)).toEqual([]);
  });

  it("counts from the original start rather than restarting at the cursor", () => {
    expect(nextOccurrences({ ...interval, count: 3 }, startAt)).toEqual(["2026-09-07T10:00:00.000Z", "2026-09-07T11:00:00.000Z"]);
    expect(nextOccurrences({ ...interval, count: 3 }, "2026-09-07T11:00:00.000Z")).toEqual([]);
  });

  it("includes until when an occurrence lands exactly on the boundary", () => {
    expect(nextOccurrences({ ...interval, until: "2026-09-07T10:00:00.000Z" }, before)).toEqual([startAt, "2026-09-07T10:00:00.000Z"]);
  });

  it("jumps over years without walking every missed minute", () => {
    expect(nextOccurrences({ ...interval, startAt: "2000-01-01T00:00:00.000Z", everySeconds: 60 }, "2099-01-01T00:00:00.000Z", 1)).toEqual(["2099-01-01T00:01:00.000Z"]);
  });

  it("caps unending rules and handles maximum representable supported year", () => {
    expect(nextOccurrences(interval, before, 100)).toHaveLength(100);
    expect(nextOccurrences({ ...interval, startAt: "9999-12-31T23:59:00.000Z", everySeconds: 60 }, "9999-12-31T23:58:00.000Z")).toEqual(["9999-12-31T23:59:00.000Z"]);
  });

  it("does not claim calendar-day semantics for 24-hour intervals", () => {
    expect(nextOccurrences({ ...interval, startAt: "2026-03-07T14:00:00.000Z", everySeconds: 86400 }, "2026-03-07T14:00:00.000Z", 1)).toEqual(["2026-03-08T14:00:00.000Z"]);
  });

  it.each(["2026-02-30T09:00:00.000Z", "2026-09-07", "2026-09-07T09:00:00+03:30", "2026-09-07T09:00:00.000", "not-a-date", null])("rejects ambiguous or invalid date %s", (value) => {
    expect(() => utcTimestamp(value)).toThrow();
  });

  it.each([
    null, [], { kind: "weekly", startAt }, { kind: "once", startAt, count: 1 },
    { ...interval, everySeconds: 0 }, { ...interval, everySeconds: 59 }, { ...interval, everySeconds: 1.5 },
    { ...interval, count: 0 }, { ...interval, count: 10001 }, { ...interval, count: "3" },
    { ...interval, until: before }, { ...interval, count: 1, until: startAt }, { ...interval, typo: true },
  ])("rejects invalid rule %#", (value) => {
    expect(() => parseSchedule(value)).toThrow();
  });

  it.each([0, 101, -1, NaN, 1.5])("rejects invalid limits %s", (limit) => {
    expect(() => nextOccurrences(interval, before, limit)).toThrow();
  });
});
