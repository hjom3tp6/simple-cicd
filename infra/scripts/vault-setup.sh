#!/bin/bash
# vault-setup.sh — 一鍵設定 Vault secrets, K8s auth, policy
# 在本機 K8s 環境使用，Vault 必須已在 vault namespace 運行
set -e

VAULT_POD="vault-0"
VAULT_NS="vault"
APP_SA="myapp-dev,myapp-prd"

echo "=== 1. 存入示範 Secret ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- vault kv put secret/myapp/config \
  API_KEY="my-super-secret-api-key-12345" \
  DB_PASSWORD="p@ssw0rd!vault-demo" \
  APP_ENV="production" \
  VAULT_DEMO="true"

echo ""
echo "=== 2. 驗證 Secret 已存入 ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- vault kv get secret/myapp/config

echo ""
echo "=== 3. 建立 Vault Policy ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- /bin/sh -c 'vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF'

echo ""
echo "=== 4. 啟用 Kubernetes Auth Method ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- vault auth enable kubernetes 2>/dev/null || echo "(已啟用)"

echo ""
echo "=== 5. 設定 Kubernetes Auth Config ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- /bin/sh -c '
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
'

echo ""
echo "=== 6. 建立 Kubernetes Auth Role ==="
kubectl exec $VAULT_POD -n $VAULT_NS -- vault write auth/kubernetes/role/myapp \
  bound_service_account_names=$APP_SA \
  bound_service_account_namespaces="dev,prd" \
  policies=myapp-policy \
  ttl=24h

echo ""
echo "=== ✅ Vault 設定完成！ ==="
echo "  - Secret 路徑: secret/myapp/config"
echo "  - Policy: myapp-policy"
echo "  - K8s Auth Role: myapp"
echo "  - 綁定 SA: $APP_SA @ dev, prd"
