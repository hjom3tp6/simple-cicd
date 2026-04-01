# 部署指南

本文件記錄將 simple-cicd 部署到本機 OrbStack Kubernetes 的完整步驟，以及完整 GitOps 流程說明。

## 前置條件

- [OrbStack](https://orbstack.dev/) 已安裝並啟用 Kubernetes
- `kubectl` 可用（OrbStack 安裝後自動設定）
- `helm` 已安裝：`brew install helm`
- Docker 可用（OrbStack 提供）

## 一次性環境設定

### 1. 安裝 Argo CD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl rollout status deployment/argocd-server -n argocd --timeout=120s
```

### 2. 設定 GHCR 私有 Repo 存取

Argo CD 需要 GitHub token（需要 `repo` 權限）才能從私有 repo 讀取 Helm chart：

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

K8s 需要 token（需要 `read:packages` 權限）才能從 GHCR 拉 image：

```bash
kubectl create namespace myapp

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=hjom3tp6 \
  --docker-password=<GITHUB_TOKEN> \
  -n myapp
```

### 3. 部署 Argo CD Application

```bash
kubectl apply -f argocd-application.yaml
```

Argo CD 會自動從 GitHub 拉取 `infra/helm/myapp/` 並部署。等待同步完成：

```bash
kubectl get application myapp -n argocd
# 等到 SYNC STATUS = Synced, HEALTH STATUS = Healthy
```

### 4. 設定 ServiceAccount 的 imagePullSecrets

Argo CD 部署後，需要手動設定 SA 的 pull secret（Helm chart 目前未內建）：

```bash
kubectl patch serviceaccount myapp -n myapp \
  -p '{"imagePullSecrets": [{"name": "ghcr-secret"}]}'
kubectl rollout restart deployment/myapp -n myapp
```

## 確認部署狀態

```bash
# Pod 狀態
kubectl get pods -n myapp

# Service / Port
kubectl get svc -n myapp

# Argo CD 同步狀態
kubectl get application myapp -n argocd -o wide
```

App 跑起來後可透過 NodePort 存取：**http://localhost:30080**

## Tailscale 網路存取

OrbStack 的 NodePort 預設只綁定 `localhost`，同一 Tailscale VPN 的裝置無法直連。用 `socat` 轉發流量：

```bash
# 安裝 socat（只需一次）
brew install socat

# 啟動轉發（100.81.101.47 替換成你的 Tailscale IP）
nohup socat TCP-LISTEN:30080,bind=100.81.101.47,fork,reuseaddr TCP:localhost:30080 \
  > /tmp/socat-30080.log 2>&1 &
```

查詢自己的 Tailscale IP：`tailscale ip -4`

啟動後，同 VPN 裝置可透過 `http://<tailscale-ip>:30080` 存取。

> **注意：** `socat` 是暫時性的，重開機後需要重新執行。如需永久化，設定成 launchd service。

## GitOps 自動部署流程

日常開發只需要：

```bash
# 修改 app/src/ 下的 Vue 原始碼
git add . && git commit -m "feat: ..."
git push
```

GitHub Actions 會自動：
1. `npm ci && npm run build`（Vite 打包）
2. `docker build & push` → GHCR（tag 為 git SHA）
3. 更新 `infra/helm/myapp/values.yaml` 的 `image.tag`
4. git commit & push

Argo CD 偵測到 `values.yaml` 變更後，自動 `helm upgrade`，約 2-3 分鐘完成部署。

### 透過 PR 部署

實際開發建議走 PR 流程，讓 CI 在 merge 後才觸發：

```bash
# 建立 feature branch
git checkout -b feat/my-feature

# 開發、commit...
git push -u origin feat/my-feature

# 建立 PR（CLI 方式）
gh pr create --title "feat: ..." --body "..."
```

merge PR 後，`main` branch 觸發 CI → 自動部署。CI workflow 只在 `app/**` 有變更時才執行（見 `.github/workflows/ci.yml` 的 `paths` 設定）。

## GitHub Actions 一次性權限設定

第一次讓 GitHub Actions 推 image 到 GHCR，需要設定兩個地方：

### 1. 開啟 Repo 的 Actions 讀寫權限

預設 `GITHUB_TOKEN` 只有讀取權限，推 package 會被拒絕。

前往 **Settings → Actions → General → Workflow permissions**，選擇 **Read and write permissions** 後儲存。

### 2. 授權 Repo 存取已存在的 GHCR Package

如果 package（`ghcr.io/<user>/<repo>/myapp`）曾經用 Personal Access Token（PAT）手動推過，它不會自動允許 `GITHUB_TOKEN` 寫入。

前往：
```
https://github.com/users/<your-username>/packages/container/<repo>%2Fmyapp/settings
```

在 **Manage Actions access** 區塊，點 **Add Repository** → 選目標 repo → 設為 **Write**。

> 這個步驟只需要做一次。之後 CI 推 image 都會使用 `GITHUB_TOKEN`，不需要 PAT。

## 本機 Build（不走 GHCR）

開發時若想快速測試，可直接 build 本機 image：

```bash
cd app
docker build -t myapp:local .

helm upgrade myapp ./infra/helm/myapp -n myapp \
  --set image.repository=myapp \
  --set image.tag=local \
  --set image.pullPolicy=Never \
  --set vault.enabled=false
```

> 注意：本機 build 後如果 Argo CD auto-sync 仍開啟，它會把 image 打回 GHCR 版本。暫停 sync：
> ```bash
> kubectl patch application myapp -n argocd \
>   -p '{"spec":{"syncPolicy":{"automated":null}}}' --type merge
> ```
