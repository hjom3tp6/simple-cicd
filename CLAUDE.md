# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

這是一個完整的 GitOps + CI/CD 學習專案，展示從程式碼推送到 Kubernetes 自動部署的完整流程。

- **Frontend**: Vue 3 + TypeScript + Vite（`app/`）
- **Container**: Docker multi-stage build → GitHub Container Registry (GHCR)
- **CI/CD**: GitHub Actions（自動 build、push image、更新 Helm values）
- **GitOps**: Argo CD 監聽 `infra/helm/myapp/values.yaml` 的 image tag 變更
- **Secrets**: HashiCorp Vault + Agent Injector（注入 `/vault/secrets/config.json`）

## 常用指令

### Frontend 開發（在 `app/` 目錄下執行）

```bash
npm install          # 安裝依賴
npm run dev          # 啟動 Vite dev server（http://localhost:5173）
npm run build        # TypeScript 型別檢查 + Vite 打包到 dist/
npm run preview      # 預覽 build 後的靜態輸出
```

### Docker

```bash
cd app
docker build -t myapp:latest .
docker run -p 3000:80 myapp:latest   # 訪問 http://localhost:3000
```

### Kubernetes（本機 OrbStack）

```bash
# 部署 Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 安裝 Vault（可選，用於 secret 示範）
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace -f infra/helm/vault-values.yaml
bash infra/scripts/vault-setup.sh   # 初始化 secrets 與 K8s auth

# 建立 Argo CD Application
kubectl apply -f argocd-application.yaml

# 訪問應用（NodePort）
http://localhost:30080
```

## 開發流程（Trunk-Based Development）

### 日常開發
1. 從 `main` 建立短命 feature branch：`feat/xxx`、`fix/xxx`
2. 在 feature branch 開發，開 PR 到 `main`
3. PR 觸發 CI：build Vue app + build Docker image（但**不 push**）
4. Review 通過後 merge → CI push image（tag: git SHA）

### 部署
只有打上 release tag 才會部署：
```bash
git tag v1.2.0
git push origin v1.2.0
```
觸發 `release.yml`：
1. Re-tag 既有 image（SHA → v1.2.0 + latest）
2. 更新 `infra/helm/myapp/values.yaml` 的 `image.tag`
3. Argo CD 偵測到變更 → 自動同步部署（約 2-3 分鐘完成）

### Branch 保護規則（在 GitHub 設定）
- `main` branch 需要 PR + CI pass 才能 merge
- 禁止直接 push to main

## 架構重點

### Vault Secret 注入機制

`infra/helm/myapp/templates/deployment.yaml` 透過 annotation 啟用 Vault Agent Injector：

- Vault Agent 以 sidecar 形式運行，將 `secret/myapp/config` 渲染為 JSON
- 掛載到 `/vault/secrets/config.json`
- nginx 設定 `location = /api/config` 直接回傳該檔案（見 `app/nginx.conf`）
- 前端 `HelloWorld.vue` fetch `/api/config` 取得 secret，並遮罩敏感值

### Image Tag 更新機制

CI pipeline (`ci.yml`) 透過 `sed` 修改 `values.yaml` 並 git commit，Argo CD 以此作為 GitOps 的 trigger，不需要直接操作 K8s cluster。

### Build Time 注入

`app/vite.config.ts` 透過 `define: { __BUILD_TIME__ }` 在 build 時注入時間戳，前端可用 `__BUILD_TIME__` 全域變數顯示部署時間。
