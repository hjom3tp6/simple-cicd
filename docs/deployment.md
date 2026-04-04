# 部署指南

本文件記錄將 simple-cicd 部署到本機 OrbStack Kubernetes 的完整步驟，以及 Dev/Prd 雙環境 GitOps 流程說明。

## 架構概覽

```
開發者 (Feature Branch)
    │  git push → PR → CI validate
    ▼
Lead merge PR → main
    │
    ├─► cd-dev.yml ──► GHCR image (SHA tag) ──► values-dev.yaml ──► ArgoCD ──► dev namespace
    │                                                                              http://localhost:30080
    │
    └─► release-please.yml ──► Release PR（自動維護版本號 + CHANGELOG）
                                    │ Lead merge
                                    ▼
                               release.yml
                                    │  crane tag（SHA → app-v*.*.*）
                                    ▼
                               values-prd.yaml ──► ArgoCD ──► prd namespace
                                                               http://localhost:30081
```

**兩個 ArgoCD Application：**

| Application | Namespace | Values Files | 觸發方式 |
|---|---|---|---|
| myapp-dev | dev | values.yaml + values-dev.yaml | cd-dev.yml 更新 image tag（SHA） |
| myapp-prd | prd | values.yaml + values-prd.yaml | release.yml 更新 image tag（app-v*.*.*） |

---

## 前置條件

- [OrbStack](https://orbstack.dev/) 已安裝並啟用 Kubernetes
- `kubectl` 可用（OrbStack 安裝後自動設定）
- `helm` 已安裝：`brew install helm`
- GitHub CLI：`brew install gh`

---

## 一次性環境設定

### 1. 安裝 Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s

# 取得初始管理員密碼
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### 2. 設定 Argo CD 存取私有 Repo

Argo CD 需要 GitHub token（`repo` 權限）才能從私有 repo 讀取 Helm chart：

```bash
kubectl create secret generic argocd-repo-hjom3tp6 \
  --from-literal=type=git \
  --from-literal=url=https://github.com/hjom3tp6/simple-cicd \
  --from-literal=username=hjom3tp6 \
  --from-literal=password=<GITHUB_TOKEN> \
  -n argocd

kubectl annotate secret argocd-repo-hjom3tp6 -n argocd "managed-by=argocd.argoproj.io"
kubectl label secret argocd-repo-hjom3tp6 -n argocd "argocd.argoproj.io/secret-type=repository"
```

### 3. 建立 GHCR 拉取 Secret（dev + prd 各一份）

Kubernetes 需要 token（`read:packages` 權限）才能從私有 GHCR 拉取 image：

```bash
# Dev namespace
kubectl create namespace dev
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=hjom3tp6 \
  --docker-password=<GITHUB_TOKEN> \
  -n dev

# Prd namespace
kubectl create namespace prd
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=hjom3tp6 \
  --docker-password=<GITHUB_TOKEN> \
  -n prd
```

> `ghcr-secret` 這個名字是 `infra/helm/myapp/values.yaml` 中 `imagePullSecrets` 指定的，不可更改。

### 4. 部署 Argo CD Application

```bash
kubectl apply -f argocd-app-dev.yaml
kubectl apply -f argocd-app-prd.yaml
```

Argo CD 自動從 GitHub 拉取 Helm chart 並部署：

```bash
kubectl get application -n argocd
# 等到兩個 SYNC STATUS = Synced, HEALTH STATUS = Healthy
```

### 5. GitHub Actions 一次性權限設定

**開啟 Repo 的 Actions 讀寫權限：**

前往 **Settings → Actions → General → Workflow permissions**，選擇 **Read and write permissions**。

**授權 GHCR Package 存取（若 package 曾用 PAT 手動推過）：**

前往：
```
https://github.com/users/hjom3tp6/packages/container/simple-cicd%2Fmyapp/settings
```

在 **Manage Actions access** → **Add Repository** → 選 `simple-cicd` → 設為 **Write**。

---

## 日常開發流程（Dev 部署）

```
feat/xxx branch
    │
    │ git push + gh pr create
    ▼
PR 觸發 ci.yml（validate）
    │  - npm ci
    │  - vue-tsc --noEmit（型別檢查）
    │  - npm run build（Vite 打包）
    │  ✓ 不 build Docker，不 push image
    ▼
Lead review & merge to main
    ▼
cd-dev.yml 觸發（paths: app/**）
    │  1. npm ci + npm run build
    │  2. docker buildx build --platform linux/amd64,linux/arm64
    │  3. push → ghcr.io/hjom3tp6/simple-cicd/myapp:<SHA>
    │  4. yq 更新 infra/helm/myapp/values-dev.yaml image.tag = <SHA>
    │  5. git commit "chore(dev): deploy <SHA>" + git push
    ▼
Argo CD 偵測到 values-dev.yaml 變更
    ▼
helm upgrade myapp-dev（dev namespace）
    ▼
http://localhost:30080 顯示新版本（約 2-3 分鐘）
```

**常用指令：**

```bash
# 建立 feature branch
git checkout -b feat/xxx main

# 推上去開 PR
git push -u origin feat/xxx
gh pr create --title "feat: ..." --body "..."

# 查看 CI 狀態
gh pr checks <PR號碼> --watch

# 查看 dev 部署狀態
kubectl get pods -n dev
kubectl get application myapp-dev -n argocd
```

---

## 上版流程（Prd 部署）

```
每次 merge to main
    ▼
release-please.yml 自動建立/更新 Release PR
    │  - 根據 Conventional Commits 計算版本號
    │  - 更新 app/package.json 版本
    │  - 更新 CHANGELOG.md
    │  - PR title: "chore(main): release app x.y.z"
    ▼
Lead 決定上版時機 → merge Release PR
    ▼
Release Please 建立 tag: app-v<x.y.z>
    ▼
release.yml 觸發（trigger: tag app-v*.*.*）
    │  1. 讀取 values-dev.yaml 的 image.tag（dev 正在跑的 SHA）
    │  2. crane tag <SHA> → app-v<x.y.z>（server-side re-tag，不需 docker pull）
    │  3. crane tag <SHA> → latest
    │  4. yq 更新 infra/helm/myapp/values-prd.yaml image.tag = app-v<x.y.z>
    │  5. git commit "chore(prd): release app-v<x.y.z>" + git push origin main
    ▼
Argo CD 偵測到 values-prd.yaml 變更
    ▼
helm upgrade myapp-prd（prd namespace）
    ▼
http://localhost:30081 顯示新版本（約 2-3 分鐘）
```

**版本號規則（Conventional Commits）：**

| Commit 前綴 | 版本變動 | 範例 |
|---|---|---|
| `fix:` | patch | v1.0.0 → v1.0.1 |
| `feat:` | minor | v1.0.0 → v1.1.0 |
| `feat!:` 或 `BREAKING CHANGE` | major | v1.0.0 → v2.0.0 |

**手動重新觸發 release（緊急情況）：**

```bash
gh workflow run release.yml --ref main -f tag=app-v1.0.0
```

---

## 確認部署狀態

```bash
# Pod 狀態
kubectl get pods -n dev
kubectl get pods -n prd

# Service / NodePort
kubectl get svc -n dev
kubectl get svc -n prd

# Argo CD 同步狀態
kubectl get application -n argocd

# 強制立即同步（不等輪詢）
kubectl annotate application myapp-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application myapp-prd -n argocd argocd.argoproj.io/refresh=hard --overwrite

# 查看 pod logs
kubectl logs -n dev -l app=myapp-dev
```

**存取地址：**
- Dev：http://localhost:30080
- Prd：http://localhost:30081

---

## Vault Secret 注入（可選）

本專案整合 HashiCorp Vault，透過 Agent Injector 將 secret 注入到 `/vault/secrets/config.json`：

```bash
# 安裝 Vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install vault hashicorp/vault -n vault --create-namespace -f infra/helm/vault-values.yaml

# 初始化 secrets 與 K8s auth
bash infra/scripts/vault-setup.sh
```

前端透過 nginx `location = /api/config` 回傳該檔案，`HelloWorld.vue` fetch `/api/config` 顯示（敏感值遮罩）。

如不需要 Vault，在 values.yaml 設定 `vault.enabled: false`。

---

## Tailscale 網路存取（可選）

OrbStack NodePort 預設只綁定 `localhost`。若需要同一 Tailscale VPN 的裝置存取，用 `socat` 轉發：

```bash
brew install socat

# 查詢 Tailscale IP
tailscale ip -4

# 轉發 dev（替換成你的 Tailscale IP）
nohup socat TCP-LISTEN:30080,bind=<TAILSCALE_IP>,fork,reuseaddr TCP:localhost:30080 \
  > /tmp/socat-30080.log 2>&1 &

# 轉發 prd
nohup socat TCP-LISTEN:30081,bind=<TAILSCALE_IP>,fork,reuseaddr TCP:localhost:30081 \
  > /tmp/socat-30081.log 2>&1 &
```

> 重開機後需要重新執行。如需永久化，設定成 launchd service。
