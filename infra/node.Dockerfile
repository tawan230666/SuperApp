FROM node:22-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
COPY packages ./packages
COPY services ./services
RUN pnpm install --no-frozen-lockfile
ARG SERVICE
RUN pnpm --filter @tipkhun/${SERVICE} build
FROM node:22-alpine
RUN corepack enable
WORKDIR /app
ARG SERVICE
COPY --from=build /repo/node_modules ./node_modules
COPY --from=build /repo/packages ./packages
COPY --from=build /repo/services/${SERVICE}/dist ./dist
COPY --from=build /repo/services/${SERVICE}/package.json ./package.json
CMD ["node", "dist/server.js"]
