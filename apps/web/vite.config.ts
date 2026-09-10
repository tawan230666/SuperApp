import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig(({mode})=>({ plugins: [react()], server: { port: 5173, allowedHosts: ["host.docker.internal"], proxy: {"/api": loadEnv(mode, process.cwd(), "").API_GATEWAY_URL ?? "http://localhost:3000"} } }));
