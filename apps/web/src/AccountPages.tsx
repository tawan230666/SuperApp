import { useEffect, useState, type FormEvent } from "react";
import { Link, Navigate, useNavigate } from "react-router-dom";
import { api, useAuth } from "./auth";
export function AuthPage({ register = false }: { register?: boolean }) {
  const { login, user, error: sessionError } = useAuth(),
    navigate = useNavigate();
  const [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [confirm, setConfirm] = useState(""),
    [error, setError] = useState(""),
    [busy, setBusy] = useState(false);
  if (user) return <Navigate to="/dashboard" replace />;
  async function submit(e: FormEvent) {
    e.preventDefault();
    setError("");
    if (register && password !== confirm) {
      setError("รหัสผ่านไม่ตรงกัน");
      return;
    }
    setBusy(true);
    try {
      if (register)
        await api("/auth/register", {
          method: "POST",
          body: JSON.stringify({ email, password }),
        });
      await login(email, password);
      navigate("/dashboard", { replace: true });
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  return (
    <main className="auth-page">
      <form className="panel auth-form" onSubmit={submit}>
        <h1>Tipkhun Capital</h1>
        <h2>{register ? "สมัครสมาชิก" : "เข้าสู่ระบบ"}</h2>
        <p>Simulation / Paper only</p>
        <label>
          Email
          <input
            aria-label="Email"
            type="email"
            required
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </label>
        <label>
          Password
          <input
            aria-label="Password"
            type="password"
            required
            minLength={12}
            maxLength={72}
            autoComplete={register ? "new-password" : "current-password"}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </label>
        {register && (
          <label>
            Confirm password
            <input
              aria-label="Confirm password"
              type="password"
              required
              autoComplete="new-password"
              value={confirm}
              onChange={(e) => setConfirm(e.target.value)}
            />
          </label>
        )}
        <small>รหัสผ่านอย่างน้อย 12 ตัวอักษร ไม่เกิน 72 bytes</small>
        {(error || sessionError) && <p role="alert">{error || sessionError}</p>}
        <button className="button primary" disabled={busy}>
          {busy ? "กำลังดำเนินการ…" : register ? "สมัครสมาชิก" : "เข้าสู่ระบบ"}
        </button>
        <Link to={register ? "/login" : "/register"}>
          {register ? "เข้าสู่ระบบ" : "สมัครสมาชิก"}
        </Link>
      </form>
    </main>
  );
}
type Plan = {
  capitalMinor: string;
  dailyLossLimitMinor: string;
  riskPerTradeMinor: string;
  maxTrades: number;
  version?: number;
};
type Profile = {
  riskTolerance: number;
  dailyLossLimit: string;
  riskPerTrade: string;
  maxTrades: number;
  maxPositions: number;
  maxDrawdown: number;
};
type Status = {
  riskUsedMinor: string;
  riskReservedMinor: string;
  riskRemainingMinor: string;
  tradesRemaining: number;
  status: string;
};
export function LiveDashboard() {
  const { user } = useAuth();
  const [data, setData] = useState<{
      plan: Plan | null;
      profile: Profile | null;
      status: Status | null;
    } | null>(null),
    [error, setError] = useState("");
  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const [plan, profile] = await Promise.all([
          api<Plan | null>("/plans/current"),
          api<Profile | null>("/risk/profile"),
        ]);
        const status =
          plan && profile ? await api<Status>("/risk/status") : null;
        if (active) setData({ plan, profile, status });
      } catch (e) {
        if (active) setError((e as Error).message);
      }
    })();
    return () => {
      active = false;
    };
  }, []);
  if (error) return <p role="alert">{error}</p>;
  if (!data) return <p role="status">กำลังโหลด Dashboard…</p>;
  return (
    <>
      <h2>ภาพรวมการเงิน</h2>
      <p>{user?.email}</p>
      {!data.plan ? (
        <section className="panel">
          <h3>สร้างแผนความเสี่ยงแรกของคุณ</h3>
          <Link to="/risk">เริ่มวางแผน</Link>
        </section>
      ) : (
        <section className="metrics">
          <article className="metric">
            <span>Capital (minor units)</span>
            <strong>{data.plan.capitalMinor}</strong>
          </article>
          <article className="metric">
            <span>Daily loss limit</span>
            <strong>{data.plan.dailyLossLimitMinor}</strong>
          </article>
          <article className="metric">
            <span>Plan version</span>
            <strong>{data.plan.version}</strong>
          </article>
          {data.status &&
            Object.entries(data.status)
              .filter(([k]) =>
                [
                  "riskUsedMinor",
                  "riskReservedMinor",
                  "riskRemainingMinor",
                  "tradesRemaining",
                  "status",
                ].includes(k),
              )
              .map(([k, v]) => (
                <article className="metric" key={k}>
                  <span>{k}</span>
                  <strong>{String(v)}</strong>
                </article>
              ))}
        </section>
      )}
      {!data.profile && <Link to="/risk">ตั้งค่า Risk Profile</Link>}
      <p>ข้อมูลจากบัญชี Simulation / Paper ของคุณ</p>
    </>
  );
}
export function RiskSettings() {
  const [plan, setPlan] = useState<Plan>({
      capitalMinor: "",
      dailyLossLimitMinor: "",
      riskPerTradeMinor: "",
      maxTrades: 3,
    }),
    [profile, setProfile] = useState<Profile>({
      riskTolerance: 500,
      dailyLossLimit: "",
      riskPerTrade: "",
      maxTrades: 3,
      maxPositions: 1,
      maxDrawdown: 1000,
    }),
    [loaded, setLoaded] = useState(false),
    [preview, setPreview] = useState(false),
    [busy, setBusy] = useState(false),
    [message, setMessage] = useState("");
  useEffect(() => {
    Promise.all([
      api<Plan | null>("/plans/current"),
      api<Profile | null>("/risk/profile"),
    ])
      .then(([p, r]) => {
        if (p) setPlan(p);
        if (r) setProfile(r);
        setLoaded(true);
      })
      .catch((e) => setMessage(e.message));
  }, []);
  async function save() {
    setBusy(true);
    setMessage("");
    try {
      await api("/risk/profile", {
        method: "PUT",
        body: JSON.stringify(profile),
      });
      const {
        capitalMinor,
        dailyLossLimitMinor,
        riskPerTradeMinor,
        maxTrades,
      } = plan;
      const saved = await api<Plan>(
        plan.version ? "/plans/current" : "/plans",
        {
          method: plan.version ? "PUT" : "POST",
          body: JSON.stringify({
            capitalMinor,
            dailyLossLimitMinor,
            riskPerTradeMinor,
            maxTrades,
          }),
        },
      );
      setPlan(saved);
      setPreview(false);
      setMessage("บันทึกแล้ว");
    } catch (e) {
      setMessage((e as Error).message);
    } finally {
      setBusy(false);
    }
  }
  if (!loaded) return <p role="status">{message || "กำลังโหลดการตั้งค่า…"}</p>;
  const high =
    /^[1-9][0-9]*$/.test(plan.capitalMinor) &&
    /^[0-9]+$/.test(plan.dailyLossLimitMinor) &&
    BigInt(plan.dailyLossLimitMinor) * 100n > BigInt(plan.capitalMinor) * 5n;
  return (
    <section className="panel">
      <h2>Risk Profile และ Investment Plan</h2>
      <p>Current Plan Version: {plan.version ?? "ยังไม่มี"}</p>
      <form
        className="risk-form"
        onSubmit={(e) => {
          e.preventDefault();
          setPreview(true);
        }}
      >
        <h3>Risk Profile</h3>
        {Object.entries(profile).map(([key, value]) => (
          <label key={key}>
            {key}
            <input
              required
              type="text"
              inputMode="numeric"
              pattern="[0-9]+"
              value={value}
              onChange={(e) => {
                setPreview(false);
                setProfile({
                  ...profile,
                  [key]:
                    typeof value === "number"
                      ? Number(e.target.value)
                      : e.target.value,
                });
              }}
            />
          </label>
        ))}
        <h3>Investment Plan — ยอดเงินเป็น minor units</h3>
        {(
          [
            "capitalMinor",
            "dailyLossLimitMinor",
            "riskPerTradeMinor",
            "maxTrades",
          ] as const
        ).map((key) => (
          <label key={key}>
            {key}
            <input
              required
              type="text"
              inputMode="numeric"
              pattern="[1-9][0-9]*"
              value={plan[key]}
              onChange={(e) => {
                setPreview(false);
                setPlan({
                  ...plan,
                  [key]:
                    key === "maxTrades"
                      ? Number(e.target.value)
                      : e.target.value,
                });
              }}
            />
          </label>
        ))}
        <p>riskTolerance / maxDrawdown เป็น basis points (100 = 1%)</p>
        <button className="button secondary" disabled={busy}>
          ดู Preview
        </button>
      </form>
      {preview && (
        <section>
          <h3>Preview — version {(plan.version ?? 0) + 1}</h3>
          <pre>{JSON.stringify({ profile, plan }, null, 2)}</pre>
          {high && (
            <p role="alert">คำเตือน: daily loss limit สูงกว่า 5% ของเงินทุน</p>
          )}
          <p>การบันทึกแผนจะสร้าง version ใหม่ Backend ตรวจสอบขั้นสุดท้าย</p>
          <button className="button primary" disabled={busy} onClick={save}>
            {busy ? "กำลังบันทึก…" : "ยืนยันบันทึก"}
          </button>
        </section>
      )}
      {message && <p role="status">{message}</p>}
    </section>
  );
}
