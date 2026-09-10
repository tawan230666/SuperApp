FROM node:24-alpine AS build
RUN corepack enable
WORKDIR /repo
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml ./
COPY packages ./packages
COPY services ./services
COPY database ./database
RUN pnpm install --frozen-lockfile
ARG SERVICE
RUN pnpm --filter @tipkhun/${SERVICE}... build
FROM node:24-alpine
WORKDIR /repo
ARG SERVICE
COPY --from=build /repo /repo
WORKDIR /repo/services/${SERVICE}
USER node
CMD ["node", "dist/server.js"]
