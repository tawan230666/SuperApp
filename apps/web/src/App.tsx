import {PortfolioPage} from "./PortfolioPage";
import { AuthProvider, useAuth } from "./auth";
import { AuthPage, LiveDashboard, RiskSettings } from "./AccountPages";
import { api } from "./auth";
import * as React from "react";
import {
  NavLink,
  Navigate,
  Route,
  Routes,
  useLocation,
} from "react-router-dom";

const nav = [
  ["/dashboard", "ภาพรวม", "⌂"],
  ["/trades", "บันทึกเทรด", "▤"],
  ["/bot", "Trading Bot", "◈"],
  ["/risk", "Risk Analytics", "◌"],
  ["/profit-router", "จัดสรรกำไร", "⇄"],
  ["/long-term", "ระยะยาว", "◫"],
  ["/assistant", "ผู้ช่วย AI", "◇"],
  ["/settings", "ตั้งค่า", "⚙"],
] as const;

type MetricProps = {
  label: string;
  value: string;
  note?: string;
  tone?: "positive" | "neutral" | "warning";
};
function Metric({ label, value, note, tone = "neutral" }: MetricProps) {
  return (
    <article className={`metric ${tone}`}>
      <span>{label}</span>
      <strong>{value}</strong>
      {note && <small>{note}</small>}
    </article>
  );
}
function Empty({ children = "ยังไม่มีข้อมูลการเทรด" }: { children?: string }) {
  return (
    <div className="empty">
      <span>◌</span>
      <p>{children}</p>
      <small>ข้อมูลจะปรากฏเมื่อมีรายการที่ตรวจสอบได้</small>
    </div>
  );
}
function Header() {
  const { logout } = useAuth();
  return (
    <header className="topbar">
      <div>
        <span className="eyebrow">TIPKHUN CAPITAL / WORKSPACE</span>
        <h1>Financial control centre</h1>
      </div>
      <div className="header-meta">
        <span className="mode">Simulation / Planning</span>
        <span className="connection">● Simulation API</span>
        <button aria-label="Notifications">♢</button>
        <button
          onClick={() => {
            logout().catch(() => window.alert("Logout ไม่สำเร็จ กรุณาลองใหม่"));
          }}
        >
          Logout
        </button>
      </div>
    </header>
  );
}
function Shell({ children }: { children: React.ReactNode }) {
  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand">
          <span className="mark">T</span>
          <span>
            Tipkhun
            <br />
            <b>Capital</b>
          </span>
        </div>
        <span className="side-label">WORKSPACE</span>
        <nav>
          {nav.map(([to, label, icon]) => (
            <NavLink
              key={to}
              to={to}
              className={({ isActive }) => (isActive ? "active" : "")}
            >
              <i>{icon}</i>
              <span>{label}</span>
            </NavLink>
          ))}
        </nav>
        <div className="side-note">
          บัญชี Simulation / Paper
          <br />
          <small>Authenticated backend</small>
        </div>
      </aside>
      <main>
        <Header />
        <div className="content">{children}</div>
        <footer>
          Simulation / Paper only · ไม่มีการส่งคำสั่งเงินจริง · Tipkhun Capital
        </footer>
      </main>
      <nav className="mobile-nav">
        {nav.slice(0, 5).map(([to, label, icon]) => (
          <NavLink key={to} to={to}>
            <i>{icon}</i>
            <small>{label}</small>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
function Panel({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <article className="panel">
      <div className="panel-head">
        <h3>{title}</h3>
        <span>⋯</span>
      </div>
      {children}
    </article>
  );
}
function Placeholder({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <>
      <div className="page-title">
        <div>
          <span className="eyebrow">TIPKHUN CAPITAL</span>
          <h2>{title}</h2>
          <p>{description}</p>
        </div>
      </div>
      <Panel title={title}>
        <Empty>{description}</Empty>
      </Panel>
    </>
  );
}
function Bot() {
  const [data, setData] = React.useState<any>(null);
  const [error, setError] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const load = React.useCallback(async () => { try { setData(await api<any>("/bot/status")); } catch (e) { setError((e as Error).message); } }, []);
  React.useEffect(() => { void load(); const timer = window.setInterval(() => void load(), 5000); return () => window.clearInterval(timer); }, [load]);
  async function control(action: string) { if (action === "emergency-stop" && !window.confirm("ยืนยัน Emergency Stop? คำสั่งค้างจะถูกยกเลิก แต่ position จะไม่ถูกปิดอัตโนมัติ")) return; setBusy(true); setError(""); try { await api(`/bot/${action}`, { method: "POST", body: "{}" }); await load(); } catch (e) { setError((e as Error).message); } finally { setBusy(false); } }
  if (error && !data) return <p role="alert">{error}</p>;
  if (!data) return <p role="status">กำลังโหลด Paper Trading…</p>;
  const account = data.account ?? {};
  return (
    <>
      <div className="page-title">
        <div>
          <span className="eyebrow">TRADING / PAPER</span>
          <h2>Trading Bot</h2>
          <p>Server-side Paper Trading · Live Trading: LOCKED</p>
        </div>
        <button
          className="button danger"
          disabled={busy} onClick={() => control("emergency-stop")}
        >
          EMERGENCY STOP
        </button>
      </div>
      {error&&<p role="alert">{error}</p>}
      <section className="metrics"><Metric label="Bot Status" value={data.state}/><Metric label="Trading Mode" value="PAPER" note="Live: LOCKED"/><Metric label="Cash" value={String(account.cashMinor ?? "—")}/><Metric label="Equity" value={String(account.equityMinor ?? "—")}/><Metric label="Daily P&L" value={String(data.dailyPnlMinor ?? "0")}/><Metric label="Open Positions" value={String(data.openPositions ?? 0)}/><Metric label="Pending Orders" value={String(data.pendingOrders ?? 0)}/><Metric label="Fees" value={String(account.feesMinor ?? "0")}/><Metric label="Broker" value={data.brokerStatus}/></section>
      <div className="status-row"><button className="button primary" disabled={busy||data.state==='RUNNING'} onClick={() => control('start')}>START</button><button className="button secondary" disabled={busy||data.state!=='RUNNING'} onClick={() => control('pause')}>PAUSE</button><button className="button secondary" disabled={busy||data.state!=='PAUSED'} onClick={() => control('resume')}>RESUME</button><button className="button secondary" disabled={busy||['STOPPED','EMERGENCY_STOPPED'].includes(data.state)} onClick={() => control('stop')}>STOP</button></div>
      <section className="grid two">
        <Panel title="Broker Connection">
          <div className="status-row">
            <span className="pill">{data.brokerStatus}</span>
            <b>Paper Broker Adapter</b> <span>Mock Broker only</span>
          </div>
          <p>Paper fills are persisted in PostgreSQL; live execution remains locked.</p>
        </Panel>
        <Panel title="Strategy & Market">
          <p>
            <b>manual-synthetic-v1</b>
            <br />
            Version hash: —<br />
            Market: SYNTHETIC-THB
            <br />
            Timeframe: Manual
            <br />
            Last heartbeat: {data.lastHeartbeat ?? "—"}
          </p>
        </Panel>
      </section>
      <Panel title="Recent Orders">
        <Empty>ใช้ GET /api/v1/orders เพื่อดูคำสั่งของคุณ</Empty>
      </Panel>
    </>
  );
}
function ProfitRouter() {
  const [available,setAvailable]=React.useState<any>(null),[settings,setSettings]=React.useState({shortTermBps:5000,longTermBps:3000,withdrawalBps:2000}),[preview,setPreview]=React.useState<any>(null),[history,setHistory]=React.useState<any[]>([]),[error,setError]=React.useState('');
  const load=React.useCallback(async()=>{try{const [a,s,h]=await Promise.all([api<any>('/allocations/available'),api<any>('/allocations/settings'),api<any[]>('/allocations/history')]);setAvailable(a);setSettings(s);setHistory(h);}catch(e){setError((e as Error).message);}},[]); React.useEffect(()=>{void load();},[load]);
  async function save(){try{await api('/allocations/settings',{method:'PUT',body:JSON.stringify(settings)});setError('บันทึกการตั้งค่าแล้ว');}catch(e){setError((e as Error).message);}}
  async function confirm(){try{await api('/allocations/confirm',{method:'POST',headers:{'Idempotency-Key':`web-${Date.now()}`},body:'{}'});setPreview(null);await load();setError('ยืนยันการจัดสรรแล้ว');}catch(e){setError((e as Error).message);}}
  if(!available)return <p role="status">กำลังโหลด Profit Router…</p>;
  return <><div className="page-title"><div><span className="eyebrow">PAPER / LEDGER</span><h2>Profit Router</h2><p>Realized net profit only · PAPER / SIMULATION</p></div></div>{error&&<p role="status">{error}</p>}<section className="metrics"><Metric label="Available realized profit" value={available.availableMinor}/><Metric label="Mode" value="PAPER"/></section><Panel title="Allocation settings"><div className="status-row">{(['shortTermBps','longTermBps','withdrawalBps'] as const).map(k=><label key={k}>{k}<input type="number" value={settings[k]} onChange={e=>setSettings({...settings,[k]:Number(e.target.value)})}/></label>)}<button className="button secondary" onClick={save}>SAVE</button></div><p>สัดส่วนต้องรวม 10000 bps</p></Panel><Panel title="Preview"><button className="button primary" onClick={async()=>setPreview(await api('/allocations/preview',{method:'POST',body:'{}'}))}>PREVIEW</button>{preview&&<><pre>{JSON.stringify(preview,null,2)}</pre><button className="button primary" onClick={confirm}>CONFIRM</button></>}</Panel><Panel title="Allocation history">{history.length?history.map(h=><p key={h.id}>{h.created_at}: {h.amount_minor} minor units</p>):<Empty>ยังไม่มี allocation</Empty>}</Panel></>;
}
function Trades() {
  return (
    <>
      <div className="page-title">
        <div>
          <span className="eyebrow">JOURNAL</span>
          <h2>บันทึกเทรด</h2>
          <p>ตารางนี้จะอ่านจาก API เดียวกับ Mobile เมื่อเชื่อมต่อ Backend</p>
        </div>
        <button className="button secondary">Export CSV</button>
      </div>
      <Panel title="Trade Journal">
        <div className="filters">
          <input placeholder="ค้นหา asset หรือ strategy" />
          <select>
            <option>ทุกสินทรัพย์</option>
          </select>
          <select>
            <option>ทุกกลยุทธ์</option>
          </select>
          <button className="button secondary">เลือกวันที่</button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                {[
                  "Date",
                  "Asset",
                  "Strategy",
                  "Side",
                  "Entry",
                  "Exit",
                  "Gross P&L",
                  "Fees",
                  "Net P&L",
                  "Risk",
                  "Mode",
                  "Status",
                ].map((h) => (
                  <th key={h}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              <tr>
                <td colSpan={12}>
                  <Empty />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </Panel>
    </>
  );
}
function Assistant() {
  return (
    <>
      <div className="page-title">
        <div>
          <span className="eyebrow">READ-ONLY COPILOT</span>
          <h2>ผู้ช่วยวางแผน</h2>
          <p>ตอบจากข้อมูลที่ได้รับอนุญาต และบอกเมื่อข้อมูลไม่เพียงพอ</p>
        </div>
      </div>
      <section className="chat">
        <div className="chat-intro">
          <span className="mark large">T</span>
          <h3>Tipkhun AI Agent</h3>
          <span className="pill muted">OFFLINE</span>
          <p>
            ยังไม่มี AI API หรือ market data provider การตอบจะใช้
            LocalAssistantService เมื่อเชื่อม session
          </p>
        </div>
        <div className="chat-empty">
          <Empty>
            เริ่มถามเรื่องงบความเสี่ยง สถานะ Paper หรือกำไรที่รับรู้
          </Empty>
        </div>
        <div className="composer">
          <input disabled placeholder="ถาม Copilot (ยังไม่เชื่อมต่อ Backend)" />
          <button disabled className="button primary">
            ส่ง
          </button>
        </div>
      </section>
    </>
  );
}
function ProtectedApp() {
  const { user, loading } = useAuth();
  const location = useLocation();
  if (loading) return <p role="status">กำลังโหลด session…</p>;
  if (location.pathname === "/login" || location.pathname === "/register")
    return <AuthPage register={location.pathname === "/register"} />;
  if (!user) return <Navigate to="/login" replace />;
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Navigate to="/dashboard" replace />} />
        <Route path="/dashboard" element={<LiveDashboard />} />
        <Route path="/trades" element={<Trades />} />
        <Route path="/bot" element={<Bot />} />
        <Route
          path="/bot/strategies"
          element={
            <Placeholder
              title="Strategy Library"
              description="ยังไม่มีกลยุทธ์ที่ผ่าน approval gate"
            />
          }
        />
        <Route
          path="/bot/backtest"
          element={
            <Placeholder
              title="Backtest Results"
              description="ยังไม่มี BacktestRun หรือ historical dataset"
            />
          }
        />
        <Route path="/risk" element={<RiskSettings />} />
        <Route
          path="/profit-router"
          element={<ProfitRouter />}
        />
        <Route
          path="/long-term"
          element={
            <PortfolioPage />
          }
        />
        <Route path="/assistant" element={<Assistant />} />
        <Route
          path="/settings"
          element={
            <Placeholder
              title="Settings"
              description="Authentication และ account settings จะอยู่ Backend"
            />
          }
        />
        <Route
          path="/login"
          element={
            <Placeholder
              title="Login"
              description="Auth service ยังไม่เปิดใช้งาน"
            />
          }
        />
        <Route
          path="/register"
          element={
            <Placeholder
              title="Register"
              description="Auth service ยังไม่เปิดใช้งาน"
            />
          }
        />
        <Route
          path="*"
          element={
            <Placeholder
              title="ไม่พบหน้านี้"
              description="เส้นทางนี้ยังไม่มีใน workspace"
            />
          }
        />
      </Routes>
    </Shell>
  );
}

export function App() {
  return (
    <AuthProvider>
      <ProtectedApp />
    </AuthProvider>
  );
}
