# === Stage 1: Build (打包階段) ===
FROM node:20-alpine AS builder

WORKDIR /app

# 先複製 package.json，利用 Docker 層快取
COPY package*.json ./
RUN npm ci

# 再複製原始碼並打包
COPY . .
RUN npm run build

# === Stage 2: Serve (服務階段) ===
FROM nginx:alpine AS runner

# 複製 Vite 打包結果到 nginx 目錄
COPY --from=builder /app/dist /usr/share/nginx/html

# 複製 nginx 設定 (SPA routing 需要)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
