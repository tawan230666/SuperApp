import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { App } from "./App";
const user = { id: "user-a", email: "a@example.test", role: "user" };
function response(body: unknown, status = 200) {
  return Promise.resolve({
    ok: status < 400,
    status,
    json: async () => body,
  } as Response);
}
function mount(path: string) {
  render(
    <MemoryRouter initialEntries={[path]}>
      <App />
    </MemoryRouter>,
  );
}
beforeEach(() => {
  vi.stubGlobal(
    "fetch",
    vi.fn(() => response({}, 401)),
  );
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});
describe("Authenticated web", () => {
  it("protects dashboard when unauthenticated", async () => {
    mount("/dashboard");
    expect(
      await screen.findByRole("heading", { name: "เข้าสู่ระบบ" }),
    ).toBeTruthy();
  });
  it("logs in and loads honest onboarding", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string) =>
        url.endsWith("/refresh")
          ? response({}, 401)
          : url.endsWith("/login")
            ? response({ accessToken: "access", user })
            : response(null),
      ),
    );
    mount("/login");
    await screen.findByLabelText("Email");
    fireEvent.change(screen.getByLabelText("Email"), {
      target: { value: user.email },
    });
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "Test-password-1234" },
    });
    fireEvent.click(screen.getByRole("button", { name: "เข้าสู่ระบบ" }));
    expect(await screen.findByText("สร้างแผนความเสี่ยงแรกของคุณ")).toBeTruthy();
  });
  it("registers then logs in", async () => {
    const fetcher = vi.fn((url: string) =>
      url.endsWith("/refresh")
        ? response({}, 401)
        : url.endsWith("/login")
          ? response({ accessToken: "access", user })
          : response(null),
    );
    vi.stubGlobal("fetch", fetcher);
    mount("/register");
    await screen.findByLabelText("Email");
    for (const label of ["Email", "Password", "Confirm password"])
      fireEvent.change(screen.getByLabelText(label), {
        target: {
          value: label === "Email" ? user.email : "Test-password-1234",
        },
      });
    fireEvent.click(screen.getByRole("button", { name: "สมัครสมาชิก" }));
    expect(await screen.findByText("สร้างแผนความเสี่ยงแรกของคุณ")).toBeTruthy();
    expect(fetcher.mock.calls.some(([url]) => url.endsWith("/register"))).toBe(
      true,
    );
  });
  it("validates confirmation", async () => {
    mount("/register");
    await screen.findByLabelText("Email");
    fireEvent.change(screen.getByLabelText("Password"), {
      target: { value: "Test-password-1234" },
    });
    fireEvent.submit(
      screen.getByRole("button", { name: "สมัครสมาชิก" }).closest("form")!,
    );
    expect((await screen.findByRole("alert")).textContent).toContain(
      "รหัสผ่านไม่ตรงกัน",
    );
  });
  it("shows dashboard loading", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string) =>
        url.endsWith("/refresh")
          ? response({ accessToken: "a" })
          : url.endsWith("/me")
            ? response(user)
            : new Promise(() => {}),
      ),
    );
    mount("/dashboard");
    expect(await screen.findByText("กำลังโหลด Dashboard…")).toBeTruthy();
  });
  it("shows API failure without invented data", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string) =>
        url.endsWith("/refresh")
          ? response({ accessToken: "a" })
          : url.endsWith("/me")
            ? response(user)
            : response({ error: "Service unavailable" }, 503),
      ),
    );
    mount("/dashboard");
    expect((await screen.findByRole("alert")).textContent).toContain(
      "Service unavailable",
    );
  });
  it("retains paper dashboard and live trading lock", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn((url: string) =>
        url.endsWith("/refresh")
          ? response({ accessToken: "a" })
          : response(user),
      ),
    );
    mount("/bot");
    expect(await screen.findByText("Live: LOCKED")).toBeTruthy();
    expect(screen.getByText("Mock Broker only")).toBeTruthy();
  });
});
