# GitOps 練習計畫書
## Vue 3 + Vite + Docker + GitHub Actions + Argo CD + Helm + OrbStack

**版本 (Version):** 1.0  
**日期 (Date):** 2026-03-31  
**目標 (Goal):** 從零開始，完整走一遍 GitOps + CI/CD 流程

---

## 目錄 (Table of Contents)

1. 技術選型說明
2. 整體架構圖
3. Repository 結構
4. 工具安裝清單
5. 階段一：前端開發與打包 (Vue 3 + Vite)
6. 階段二：容器化 (Docker)
7. 階段三：CI 自動化 (GitHub Actions)
8. 階段四：基礎設施即程式碼 (Helm Chart)
9. 階段五：GitOps 部署 (Argo CD)
10. 完整流程圖
11. 學習重點總結

---

## 1. 技術選型說明 (Tech Choices)

| 類別 (Category) | 工具 (Tool) | 理由 (Why) |
|---|---|---|
| 前端框架 | Vue 3 | 主流、易學、生態豐富 |
| 打包工具 | Vite | Vue 官方推薦，啟動速度極快 |
| 語言 | TypeScript | 現代 Vue 3 專案標準 |
| 容器 | Docker + nginx:alpine | 輕量、適合靜態網站 |
| 映像倉庫 | GHCR (GitHub Container Registry) | 免費、與 GitHub 整合 |
| CI | GitHub Actions | 免費、與 GitHub 原生整合 |
| K8s 環境 | OrbStack (本機) | macOS 上最輕量的 K8s |
| 打包管理 | Helm | K8s 套件管理標準 |
| GitOps | Argo CD | 最主流的 GitOps 工具 |

---

## 2. 整體架構圖 (Architecture Overview)

```
開發者 (You)
    │
    │  git push (修改 Vue 原始碼)
    ▼
┌─────────────────────────────────────┐
│           GitHub Repository         │
│                                     │
│  ┌──────────┐    ┌───────────────┐  │
│  │  app/    │    │   infra/      │  │
│  │ (Vue src)│    │ (Helm charts) │  │
│  └──────────┘    └───────────────┘  │
└──────────┬──────────────▲───────────┘
           │              │
           │ trigger      │ git push (更新 image tag)
           ▼              │
┌──────────────────────┐  │
│   GitHub Actions     │  │
│   (CI Pipeline)      │──┘
│                      │
│  1. npm install      │
│  2. npm run build    │──► /dist 靜態檔案
│  3. docker build     │
│  4. docker push      │──► GHCR (映像倉庫)
│  5. update tag       │
└──────────────────────┘

           Argo CD 持續監控 infra/ 資料夾
                      │
                      │ 偵測到 Helm values 改變
                      ▼
┌─────────────────────────────────────┐
│       OrbStack Kubernetes           │
│                                     │
│  ┌──────────┐    ┌──────────────┐   │
│  │ Argo CD  │───►│  myapp 應用  │   │
│  │(argocd)  │    │ (myapp ns)   │   │
│  └──────────┘    └──────┬───────┘   │
│                         │           │
│                  nginx 提供服務      │
│               http://myapp.local    │
└─────────────────────────────────────┘
```

---

## 3. Repository 結構 (Repo Structure)

使用**單一 repo**，用資料夾分開 app 和 infra：

```
my-gitops-practice/
│
├── app/                          ← 前端 Vue 原始碼
│   ├── src/
│   │   ├── App.vue
│   │   ├── main.ts
│   │   └── components/
│   │       └── HelloWorld.vue
│   ├── public/
│   │   └── favicon.ico
│   ├── index.html
│   ├── vite.config.ts
│   ├── tsconfig.json
│   ├── package.json
│   └── Dockerfile               ← 打包 + nginx
│
├── infra/                        ← Argo CD 監控這裡
│   └── helm/
│       └── myapp/
│           ├── Chart.yaml
│           ├── values.yaml       ← CI 會自動更新 image tag
│           └── templates/
│               ├── deployment.yaml
│               ├── service.yaml
│               └── ingress.yaml
│
└── .github/
    └── workflows/
        └── ci.yml                ← GitHub Actions CI 流程
```

---

## 4. 工具安裝清單 (Installation Checklist)

在開始之前，確認以下工具都已安裝：

```
本機 (Mac)
├── [ ] OrbStack — 下載安裝，Settings > Kubernetes > Enable
├── [ ] kubectl  — brew install kubectl
├── [ ] helm     — brew install helm
├── [ ] argocd   — brew install argocd (CLI)
├── [ ] Node.js  — brew install node (v20+)
└── [ ] Docker   — OrbStack 內建，不需另外安裝

GitHub
├── [ ] 建立新的 Repository
├── [ ] 開啟 GitHub Container Registry (GHCR)
│       Settings > Packages > 確認 GHCR 啟用
└── [ ] 設定 GitHub Actions Secrets
        GITHUB_TOKEN — 自動存在，不需手動設定
```

---

## 5. 階段一：前端開發與打包 (Vue 3 + Vite)

### 5.1 Vite 是什麼？為什麼用它？

**Vite** (法文「快速」) 是 Vue 官方推薦的打包工具。

| 比較項目 | 傳統 Webpack | Vite |
|---|---|---|
| 開發啟動速度 | 慢 (10+ 秒) | 超快 (< 1 秒) |
| 熱更新 (HMR) | 慢 (5+ 秒) | 幾乎即時 |
| 設定複雜度 | 高 | 低 |
| 生產打包工具 | Webpack | Rolldown (Rollup) |
| Vue 官方推薦 | ❌ 已停止維護 | ✅ 官方推薦 |

### 5.2 Vite 打包流程說明

```
開發環境 (npm run dev)
─────────────────────────────────────────────
原始碼 .vue .ts  →  Vite Dev Server  →  瀏覽器
                     (ES Module，不打包)
                     HMR 熱更新極快

生產環境 (npm run build)
─────────────────────────────────────────────
原始碼 .vue .ts
    │
    ▼ Vite 處理
    ├── 編譯 .vue → JS + CSS
    ├── 編譯 TypeScript → JavaScript
    ├── Tree-shaking (移除沒用到的程式碼)
    ├── Code-splitting (分割成多個小檔案)
    ├── Minify (壓縮)
    └── Hash 檔名 (避免快取問題)
    │
    ▼ 輸出 dist/
    ├── index.html
    ├── assets/main.a1b2c3d4.js    ← hash 檔名
    ├── assets/main.e5f6g7h8.css
    └── assets/vendor.i9j0k1l2.js  ← 第三方套件分離
```

### 5.3 重要設定檔說明

**`vite.config.ts`**
```typescript
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'dist',        // 輸出資料夾
    sourcemap: false,      // 生產環境關閉 sourcemap
    rollupOptions: {
      output: {
        // 手動分離 vendor 套件 (效能優化)
        manualChunks: {
          vendor: ['vue', 'vue-router']
        }
      }
    }
  }
})
```

**`package.json` 關鍵腳本**
```json
{
  "scripts": {
    "dev":     "vite",              // 本機開發
    "build":   "vue-tsc && vite build",  // 打包 (先型別檢查再打包)
    "preview": "vite preview",      // 預覽打包結果
    "lint":    "eslint . --ext .vue,.ts" // 程式碼檢查
  }
}
```

---

## 6. 階段二：容器化 (Docker)

### 6.1 Dockerfile 說明

使用**多階段打包 (Multi-stage Build)**，這是最佳實踐：

```dockerfile
# === Stage 1: Build (打包階段) ===
FROM node:20-alpine AS builder

WORKDIR /app

# 先複製 package.json，利用 Docker 層快取
# 只有 package.json 改變時才重新 npm install
COPY package*.json ./
RUN npm ci --frozen-lockfile

# 再複製原始碼並打包
COPY . .
RUN npm run build
# 此時 /app/dist 有所有靜態檔案

# === Stage 2: Serve (服務階段) ===
FROM nginx:alpine AS runner

# 複製 Vite 打包結果到 nginx 目錄
COPY --from=builder /app/dist /usr/share/nginx/html

# 複製 nginx 設定 (SPA routing 需要)
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

**為什麼用多階段打包？**
- Stage 1 (builder): 包含 Node.js、npm、原始碼 → 映像很大 (400MB+)
- Stage 2 (runner): 只有 nginx + dist 靜態檔 → 映像很小 (< 30MB)
- 最終映像只有 Stage 2，安全又輕量

### 6.2 nginx.conf (SPA 路由設定)

```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    # Vue Router 需要這段
    # 所有路由都返回 index.html，讓 Vue 前端處理路由
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 靜態資源快取設定
    location /assets {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

## 7. 階段三：CI 自動化 (GitHub Actions)

### 7.1 CI 流程說明

```
觸發條件：push 到 main branch，且 app/ 資料夾有改變

Job: build-and-push
│
├── Step 1: Checkout 程式碼
├── Step 2: Setup Node.js 20
├── Step 3: npm ci (安裝依賴)
├── Step 4: npm run build (Vite 打包)
│           └── 輸出 app/dist/
├── Step 5: 登入 GHCR
├── Step 6: docker build & push
│           └── tag: ghcr.io/USER/REPO/myapp:SHA
└── Step 7: 更新 infra/helm/myapp/values.yaml
            └── 把 image.tag 改成新的 SHA
            └── git commit & push
            (這步是 GitOps 的關鍵！)
```

### 7.2 `.github/workflows/ci.yml`

```yaml
name: CI - Build and Deploy

on:
  push:
    branches: [main]
    paths:
      - 'app/**'  # 只有 app 資料夾改變才觸發

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/myapp

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: write        # 需要 push infra 的改動
      packages: write        # 需要 push 到 GHCR

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: app/package-lock.json

      - name: Install dependencies
        working-directory: app
        run: npm ci

      - name: Build (Vite)
        working-directory: app
        run: npm run build
        # 輸出在 app/dist/

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and Push Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./app
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest

      # GitOps 的關鍵步驟：
      # CI 自動更新 Helm values，讓 Argo CD 知道要換新版本
      - name: Update image tag in Helm values
        run: |
          sed -i "s|tag:.*|tag: \"${{ github.sha }}\"|" \
            infra/helm/myapp/values.yaml
          git config user.email "github-actions@github.com"
          git config user.name "GitHub Actions"
          git add infra/helm/myapp/values.yaml
          git commit -m "chore: update image tag to ${{ github.sha }}"
          git push
```

---

## 8. 階段四：基礎設施即程式碼 (Helm Chart)

### 8.1 Helm 是什麼？

Helm 是 Kubernetes 的「套件管理工具」，就像 npm 之於 Node.js。

- **Chart** = 一個應用的所有 K8s 設定模板
- **Values** = 可以替換的變數 (如 image tag, replica 數量)
- **Release** = 一次部署的實例

### 8.2 `infra/helm/myapp/Chart.yaml`

```yaml
apiVersion: v2
name: myapp
description: My Vue 3 GitOps Practice App
type: application
version: 0.1.0        # Chart 版本
appVersion: "1.0.0"   # 應用版本
```

### 8.3 `infra/helm/myapp/values.yaml`

```yaml
# CI 會自動更新 image.tag 這個值
image:
  repository: ghcr.io/YOUR_USERNAME/YOUR_REPO/myapp
  tag: "latest"    # ← CI 自動把這裡改成 git SHA
  pullPolicy: IfNotPresent

replicaCount: 1

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  host: myapp.local    # 本機用 hosts 設定

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

### 8.4 `templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: myapp
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
```

---

## 9. 階段五：GitOps 部署 (Argo CD)

### 9.1 GitOps 核心概念

**GitOps 的原則：**
> Git 是唯一的「真相來源 (Single Source of Truth)」  
> 所有基礎設施的狀態都用 Git 版本控制  
> 系統自動讓實際狀態 = Git 中定義的狀態

```
傳統部署方式：
  工程師 → 手動 kubectl apply → Cluster
  問題：誰改了什麼？沒有記錄，難以回滾

GitOps 方式：
  工程師 → git push → Argo CD 自動同步 → Cluster
  優點：所有改動都在 Git 有記錄，可以輕鬆 revert
```

### 9.2 安裝 Argo CD

```bash
# 建立 namespace
kubectl create namespace argocd

# 安裝 Argo CD
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 等待所有 pod 都 Running
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s

# 取得管理員密碼
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 開啟瀏覽器介面 (另開一個 terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 瀏覽器開啟: https://localhost:8080
# 帳號: admin, 密碼: 上面取得的密碼
```

### 9.3 建立 Argo CD Application

```yaml
# 檔案: argocd-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/YOUR_USERNAME/my-gitops-practice
    targetRevision: main
    path: infra/helm/myapp      # Helm chart 路徑
    helm:
      valueFiles:
        - values.yaml

  destination:
    server: https://kubernetes.default.svc
    namespace: myapp            # 部署到這個 namespace

  syncPolicy:
    automated:                  # 自動同步！GitOps 的核心
      prune: true               # 刪除 Git 裡沒有的資源
      selfHeal: true            # 有人手動改了 cluster？自動還原
    syncOptions:
      - CreateNamespace=true    # 自動建立 namespace
```

```bash
# 部署 Argo CD Application
kubectl apply -f argocd-application.yaml

# 查看狀態
argocd app get myapp
argocd app sync myapp  # 手動觸發第一次同步
```

### 9.4 本機 Ingress 設定

```bash
# 安裝 nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

# 設定本機 hosts (讓 myapp.local 指向本機)
echo "127.0.0.1 myapp.local" | sudo tee -a /etc/hosts

# 之後就可以用瀏覽器開啟
# http://myapp.local
```

---

## 10. 完整 GitOps 流程 (Full Flow)

```
你改了一行 Vue 程式碼：
修改 app/src/App.vue

      git add . && git commit -m "feat: update homepage"
      git push origin main
             │
             ▼
    ┌─────────────────────┐
    │   GitHub Actions    │  觸發！因為 app/ 有改動
    │                     │
    │  1. npm ci          │
    │  2. npm run build   │  Vite 打包 → dist/
    │  3. docker build    │  多階段建置
    │  4. docker push     │  推送到 GHCR
    │     tag: abc123     │
    │  5. git push        │  更新 values.yaml tag: abc123
    └─────────────────────┘
             │
             │ (infra/ 有了新的 commit)
             ▼
    ┌─────────────────────┐
    │     Argo CD         │  每 3 分鐘輪詢一次 (或 webhook 即時)
    │                     │
    │  偵測到 values.yaml │
    │  image.tag 改變了   │
    │                     │
    │  helm upgrade myapp │  自動更新！
    │  --set image.tag=   │
    │    abc123           │
    └─────────────────────┘
             │
             ▼
    ┌─────────────────────┐
    │  OrbStack K8s       │
    │                     │
    │  舊 Pod 優雅終止    │
    │  新 Pod 啟動        │  拉取新映像 abc123
    │  健康檢查通過        │
    └─────────────────────┘
             │
             ▼
    http://myapp.local  ← 你的新版網站上線！🎉
    
整個過程：約 2-3 分鐘，全自動，你只需要 git push！
```

---

## 11. 學習重點總結 (Key Learnings)

### 你會學到的技能

**前端 (Frontend)**
- Vue 3 Composition API 基本用法
- Vite 打包流程與設定
- TypeScript 基礎
- 多階段 Docker build

**CI/CD**
- GitHub Actions 工作流程設計
- Docker 映像建置與推送
- GHCR 映像倉庫使用

**Kubernetes**
- Pod, Deployment, Service, Ingress 概念
- kubectl 基本操作
- Namespace 管理

**Helm**
- Chart 結構理解
- Values 覆蓋機制
- helm install / upgrade / rollback

**GitOps**
- Argo CD 安裝與設定
- Application 資源定義
- 自動同步 (automated sync)
- Self-healing 概念
- Git 作為 Single Source of Truth

### 練習建議

```
第 1 週：前端基礎
├── 建立 Vue 3 + Vite 專案
├── 理解 Vite 打包輸出
└── 撰寫 Dockerfile，本機 docker build & run

第 2 週：CI 自動化
├── 建立 GitHub repo
├── 設定 GitHub Actions
└── 確認 GHCR 映像推送成功

第 3 週：K8s + Helm
├── 啟用 OrbStack Kubernetes
├── 手動 helm install 部署
└── 確認網站可以在本機訪問

第 4 週：GitOps
├── 安裝 Argo CD
├── 設定 Application 自動同步
└── 測試完整流程：改程式碼 → git push → 自動部署
```

---

**完成這個練習後，你就擁有了現代雲端工程師的核心技能！** 🚀

---
*本計畫書由 Claude 協助生成 | 技術版本截至 2026 年
