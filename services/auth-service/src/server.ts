import { baseApp, authRoutes, finish } from "@tipkhun/auth";
export const app = baseApp("auth-service");
app.use("/v1/auth", authRoutes());
finish(app);
if (process.env.NODE_ENV !== "test")
  app.listen(Number(process.env.AUTH_PORT ?? 3002));
