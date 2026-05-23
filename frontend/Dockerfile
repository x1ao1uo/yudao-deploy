FROM node:22-alpine AS build

WORKDIR /app

ARG PNPM_VERSION=9.15.9
RUN corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate

ENV NODE_OPTIONS=--max-old-space-size=2048

COPY yudao-ui-admin-vue3/package.json yudao-ui-admin-vue3/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY yudao-ui-admin-vue3/ ./

ARG VITE_BASE_URL=
ARG VITE_API_URL=/admin-api
ARG VITE_BASE_PATH=/
ARG VITE_OUT_DIR=dist-docker
ARG VITE_APP_DEFAULT_LOGIN_TENANT=

RUN printf '%s\n' \
    'NODE_ENV=production' \
    'VITE_DEV=false' \
    "VITE_BASE_URL=${VITE_BASE_URL}" \
    "VITE_API_URL=${VITE_API_URL}" \
    "VITE_BASE_PATH=${VITE_BASE_PATH}" \
    "VITE_OUT_DIR=${VITE_OUT_DIR}" \
    "VITE_APP_DEFAULT_LOGIN_TENANT=${VITE_APP_DEFAULT_LOGIN_TENANT}" \
    'VITE_DROP_DEBUGGER=true' \
    'VITE_DROP_CONSOLE=true' \
    'VITE_SOURCEMAP=false' \
    > .env.docker

RUN pnpm exec vite build --mode docker

FROM nginx:1.27-alpine

COPY yudao-deploy/frontend/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist-docker /usr/share/nginx/html

EXPOSE 80
