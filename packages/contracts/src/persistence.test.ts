import { describe, it, expect } from "vitest";
import {
  persistedMinorSchema,
  investmentPlanSchema,
  authCredentialsSchema,
  proposedRiskSchema,
} from "./index.js";
describe("Persistence contracts", () => {
  it("retains bigint precision", () =>
    expect(persistedMinorSchema.parse("9007199254740993")).toBe(
      "9007199254740993",
    ));
  it.each([1.5, 100, "1.5", "01", "-1", "9223372036854775808"])(
    "rejects invalid money %s",
    (v) => expect(persistedMinorSchema.safeParse(v).success).toBe(false),
  );
  it("rejects limits above capital", () =>
    expect(
      investmentPlanSchema.safeParse({
        capitalMinor: "100",
        dailyLossLimitMinor: "101",
        riskPerTradeMinor: "1",
        maxTrades: 3,
      }).success,
    ).toBe(false));
  it("rejects client identity and limits in proposal", () =>
    expect(
      proposedRiskSchema.safeParse({ proposedRiskMinor: "1", userId: "x" })
        .success,
    ).toBe(false));
  it("rejects bcrypt byte truncation", () =>
    expect(
      authCredentialsSchema.safeParse({
        email: "x@example.test",
        password: "ก".repeat(30),
      }).success,
    ).toBe(false));
});
