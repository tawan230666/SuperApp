import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
export type User = { id: string; email: string; role: string };
let accessToken: string | null = null;
let refreshing: Promise<boolean> | null = null;
export async function refresh() {
  if (!refreshing)
    refreshing = (async () => {
      const response = await fetch("/api/v1/auth/refresh", {
        method: "POST",
        credentials: "include",
        headers: { "content-type": "application/json", "x-auth-client": "web" },
        body: "{}",
      });
      if (!response.ok) {
        accessToken = null;
        return false;
      }
      accessToken = (await response.json()).accessToken;
      return true;
    })().finally(() => {
      refreshing = null;
    });
  return refreshing;
}
export async function api<T>(
  path: string,
  options: RequestInit = {},
  retry = true,
): Promise<T> {
  const response = await fetch(`/api/v1${path}`, {
    ...options,
    credentials: "include",
    headers: {
      "content-type": "application/json",
      "x-auth-client": "web",
      ...(accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
      ...(options.headers as Record<string, string> | undefined),
    },
  });
  if (
    response.status === 401 &&
    retry &&
    (!path.startsWith("/auth/") || path === "/auth/logout") &&
    (await refresh())
  )
    return api(path, options, false);
  if (response.status === 401 && !path.startsWith("/auth/"))
    window.dispatchEvent(new Event("tipkhun-session-expired"));
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error ?? "เชื่อมต่อ API ไม่สำเร็จ");
  }
  return response.status === 204 ? (undefined as T) : response.json();
}
const Context = createContext<{
  user: User | null;
  loading: boolean;
  error: string;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}>({
  user: null,
  loading: true,
  error: "",
  login: async () => {},
  logout: async () => {},
});
export const useAuth = () => useContext(Context);
export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null),
    [loading, setLoading] = useState(true),
    [error, setError] = useState("");
  useEffect(() => {
    const expired = () => setUser(null);
    window.addEventListener("tipkhun-session-expired", expired);
    let active = true;
    (async () => {
      try {
        if (await refresh()) {
          const u = await api<User>("/me");
          if (active) setUser(u);
        }
      } catch {
        if (active) setError("โหลด session ไม่สำเร็จ กรุณาเข้าสู่ระบบอีกครั้ง");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
      window.removeEventListener("tipkhun-session-expired", expired);
    };
  }, []);
  async function login(email: string, password: string) {
    const result = await api<{ accessToken: string; user: User }>(
      "/auth/login",
      { method: "POST", body: JSON.stringify({ email, password }) },
    );
    accessToken = result.accessToken;
    setUser(result.user);
    setError("");
  }
  async function logout() {
    await api("/auth/logout", { method: "POST" });
    accessToken = null;
    setUser(null);
  }
  return (
    <Context.Provider value={{ user, loading, error, login, logout }}>
      {children}
    </Context.Provider>
  );
}
