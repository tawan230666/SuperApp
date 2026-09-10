import { AuthProvider, useAuth } from "./auth";
import { AuthPage, LiveDashboard, RiskSettings } from "./AccountPages";
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
  return (
    <>
      <div className="page-title">
        <div>
          <span className="eyebrow">TRADING / PAPER</span>
          <h2>Trading Bot</h2>
          <p>Risk gateway และสถานะคำสั่งในพื้นที่จำลอง</p>
        </div>
        <button
          className="button danger"
          onClick={() =>
            window.alert(
              "Emergency Stop ต้องยืนยันใน Flutter Paper client หรือ API ที่ได้รับอนุญาต",
            )
          }
        >
          Emergency Stop
        </button>
      </div>
      <section className="metrics">
        <Metric
          label="Bot Status"
          value="READY"
          note="ยังไม่ได้เริ่ม Paper session"
        />
        <Metric label="Trading Mode" value="PAPER" note="Live: LOCKED" />
        <Metric
          label="Risk Remaining"
          value="—"
          note="Risk service unavailable"
          tone="warning"
        />
        <Metric label="Open Positions" value="0" />
        <Metric label="Pending Orders" value="0" />
        <Metric label="AI Agent" value="OFFLINE" />
      </section>
      <section className="grid two">
        <Panel title="Broker Connection">
          <div className="status-row">
            <span className="pill muted">DISCONNECTED</span>
            <b>Mock Broker only</b>
          </div>
          <p>ยังไม่มี backend service ที่รับผิดชอบ execution</p>
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
            Last market update: —
          </p>
        </Panel>
      </section>
      <Panel title="Recent Orders">
        <Empty>ยังไม่มีคำสั่งใน Paper session</Empty>
      </Panel>
    </>
  );
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
          element={
            <Placeholder
              title="Profit Router"
              description="ยังไม่มี realized net profit ที่จัดสรรได้"
            />
          }
        />
        <Route
          path="/long-term"
          element={
            <Placeholder
              title="Long-Term Portfolio"
              description="ยังไม่มี holdings หรือ market data จริง"
            />
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
