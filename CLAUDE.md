# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 專案概述

這是一個完整的 GitOps + CI/CD 學習專案，展示從程式碼推送到 Kubernetes 自動部署的完整流程。

- **Frontend**: Vue 3 + TypeScript + Vite（`app/`）
- **Container**: Docker multi-stage build → GitHub Container Registry (GHCR)
- **CI/CD**: GitHub Actions（PR 驗證 → Dev 自動部署 → Release Please → Prd 部署）
- **GitOps**: Argo CD 監聽 `values-dev.yaml` / `values-prd.yaml` 的 image tag 變更
- **Environments**: `dev` namespace（自動部署）+ `prd` namespace（Release Please 上版）
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

# 建立 Argo CD Application（dev + prd）
kubectl apply -f argocd-app-dev.yaml
kubectl apply -f argocd-app-prd.yaml

# 訪問應用（NodePort）
# Dev:  http://localhost:30080
# Prd:  http://localhost:30081
```

## 開發流程（Trunk-Based Development）

### 角色劃分
- **Developer**：開發功能、開 PR
- **Lead**：Review PR、merge 到 main、決定上版時機（merge Release PR）

### 日常開發
1. 從 `main` 建立短命 feature branch：`feat/xxx`、`fix/xxx`
2. 在 feature branch 開發，開 PR 到 `main`
3. PR 觸發 `ci.yml`：type check + Vite build（**不 build Docker、不 push**）
4. Lead review 通過後 merge → `cd-dev.yml` build + push image（tag: SHA）→ 更新 `values-dev.yaml` → Argo CD 自動部署到 `dev` namespace

### CI 自動檢查與修復（IMPORTANT）

**每次開完 PR 之後，必須執行以下流程，不需要使用者提醒：**

1. 等待 CI 執行（用 `gh pr checks <PR號碼>` 輪詢，每 15 秒檢查一次，直到有結果）
2. 若 CI 失敗：
   - 用 `gh run view <run_id> --log-failed` 查看錯誤訊息
   - 診斷並修復問題
   - commit + push 修復
   - 回到步驟 1 重新等待 CI
3. 若 CI 連續失敗超過 3 次修復嘗試：停止修復，回報目前狀況與錯誤訊息，等待使用者判斷
4. 若 CI 通過：告知使用者 PR 已就緒，CI 全部通過

```bash
# 輪詢 CI 狀態的指令
gh pr checks <PR號碼> --watch   # 持續等待直到完成
# 或手動輪詢
gh pr checks <PR號碼>
gh run view <run_id> --log-failed
```

### 上版流程（Release Please）
1. 每次 merge 到 main，`release-please.yml` 自動建立/更新一個 **Release PR**
2. Release PR 包含：自動計算的版本號 + CHANGELOG（根據 Conventional Commits）
3. Lead 決定上版時機 → merge Release PR
4. Release Please 自動建立 tag（e.g. `v1.2.0`）+ GitHub Release
5. `release.yml` 觸發：
   - 從 `values-dev.yaml` 讀取 dev 正在跑的 image SHA（**確保 prd 部署的跟 dev 驗證過的一致**）
   - 用 `crane tag` 做 server-side re-tag（SHA → version + latest）
   - 更新 `values-prd.yaml`
   - Argo CD 自動同步部署到 `prd` namespace（約 2-3 分鐘）

### Conventional Commits 版本規則
- `fix:` → patch bump（e.g. v1.0.0 → v1.0.1）
- `feat:` → minor bump（e.g. v1.0.0 → v1.1.0）
- `feat!:` 或 `BREAKING CHANGE` → major bump（e.g. v1.0.0 → v2.0.0）

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

### Image Tag 更新機制（雙環境）

- **Dev**：`cd-dev.yml` 用 `yq` 更新 `values-dev.yaml` 的 `image.tag` 為 commit SHA，git commit+push
- **Prd**：`release.yml` 讀取 `values-dev.yaml` 的 SHA，用 `crane tag` re-tag 後，更新 `values-prd.yaml` 為版本號
- Argo CD 監聽各自的 values file 變更，自動同步對應 namespace

### Build Time 注入

`app/vite.config.ts` 透過 `define: { __BUILD_TIME__ }` 在 build 時注入時間戳，前端可用 `__BUILD_TIME__` 全域變數顯示部署時間。

## AI 自動實作模式（GitHub Actions 環境）

當 Claude 透過 `claude-implement.yml` workflow 在 GitHub Actions 中執行時，遵循以下額外規則：

### 觸發方式
對 issue 加上 **`ai-task`** label → `claude-implement.yml` 自動觸發 → Claude 讀取 issue 並實作 → 開 PR 等待 review。

### 範圍限制
- 預設只修改 `app/` 和 `docs/` 目錄
- 若 issue 明確要求其他範圍（如 `infra/`），可以修改，但需在 PR 說明原因
- **絕對不修改** `.github/workflows/` 下的任何檔案（防止 workflow injection）
- 不修改根目錄的 ArgoCD 設定檔（`argocd-app-*.yaml`）

### 實作流程
1. 仔細閱讀 issue 的標題、描述與驗收條件
2. 分析需要修改的檔案
3. 實作變更（TypeScript 優先，不寫 JavaScript）
4. 在 `app/` 目錄下執行 `npm install && npm run build` 驗證
5. 使用 Conventional Commits 格式 commit（`feat:`, `fix:`, `docs:`, `chore:`）
6. 建立 PR，描述使用繁體中文

### 無法處理的情況
若遇到以下情況，在 issue 留言說明原因，**不建立 PR**：
- Issue 描述太模糊，無法判斷具體需求
- 需要大量架構變更（超過 10 個檔案）
- 涉及安全敏感操作（secrets、權限設定、外部 API key）
