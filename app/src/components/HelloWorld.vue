<script setup lang="ts">
import { ref, onMounted } from 'vue'

const count = ref(0)
const buildTime = __BUILD_TIME__

interface VaultConfig {
  API_KEY: string
  APP_ENV: string
  DB_PASSWORD: string
  VAULT_DEMO: string
}

const vaultConfig = ref<VaultConfig | null>(null)
const vaultError = ref('')

onMounted(async () => {
  try {
    const res = await fetch('/api/config')
    if (res.ok) {
      vaultConfig.value = await res.json()
    } else {
      vaultError.value = `HTTP ${res.status} — Vault secret 尚未注入`
    }
  } catch {
    vaultError.value = '無法讀取 Vault config（可能尚未啟用 Vault）'
  }
})

function maskSecret(value: string): string {
  if (value.length <= 4) return '****'
  return value.slice(0, 4) + '*'.repeat(value.length - 4)
}
</script>

<template>
  <div class="container">
    <h1>🚀 GitOps Practice App</h1>
    <p class="subtitle">Vue 3 + Vite + Docker + Helm + Argo CD + Vault</p>

    <div class="card">
      <button @click="count++">Count is {{ count }}</button>
      <p>Edit <code>src/components/HelloWorld.vue</code> to test HMR</p>
    </div>

    <div class="info">
      <h2>Tech Stack</h2>
      <ul>
        <li>⚡ Vite — 極速打包工具</li>
        <li>💚 Vue 3 — Composition API</li>
        <li>🐳 Docker — 多階段打包</li>
        <li>⎈ Helm — K8s 套件管理</li>
        <li>🔄 Argo CD — GitOps 部署</li>
        <li>🔐 Vault — Secret 安全管理</li>
      </ul>
    </div>

    <div class="vault-section">
      <h2>🔐 Vault Secrets</h2>
      <div v-if="vaultConfig" class="vault-config">
        <table>
          <tr>
            <td class="key">APP_ENV</td>
            <td>{{ vaultConfig.APP_ENV }}</td>
          </tr>
          <tr>
            <td class="key">API_KEY</td>
            <td class="secret">{{ maskSecret(vaultConfig.API_KEY) }}</td>
          </tr>
          <tr>
            <td class="key">DB_PASSWORD</td>
            <td class="secret">{{ maskSecret(vaultConfig.DB_PASSWORD) }}</td>
          </tr>
          <tr>
            <td class="key">VAULT_DEMO</td>
            <td>{{ vaultConfig.VAULT_DEMO }}</td>
          </tr>
        </table>
        <p class="vault-note">✅ Secret 由 Vault Agent Injector 自動注入</p>
      </div>
      <div v-else-if="vaultError" class="vault-error">
        <p>⚠️ {{ vaultError }}</p>
      </div>
      <div v-else class="vault-loading">
        <p>載入中...</p>
      </div>
    </div>

    <p class="build-info">Build time: {{ buildTime }}</p>
  </div>
</template>

<style scoped>
.container {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

h1 {
  font-size: 2rem;
  margin-bottom: 0.5rem;
}

.subtitle {
  color: #888;
  margin-bottom: 2rem;
}

.card {
  padding: 1.5rem;
  border: 1px solid #333;
  border-radius: 8px;
  margin-bottom: 2rem;
}

.card button {
  font-size: 1rem;
  padding: 0.6rem 1.2rem;
  border-radius: 8px;
  border: 1px solid transparent;
  background-color: #1a1a1a;
  color: #fff;
  cursor: pointer;
  transition: border-color 0.25s;
}

.card button:hover {
  border-color: #646cff;
}

.info {
  text-align: left;
  padding: 1rem;
}

.info ul {
  list-style: none;
  padding: 0;
}

.info li {
  padding: 0.3rem 0;
}

.vault-section {
  margin-top: 1.5rem;
  padding: 1.5rem;
  border: 1px solid #2a5a2a;
  border-radius: 8px;
  background: #0a1a0a;
}

.vault-config table {
  width: 100%;
  text-align: left;
  border-collapse: collapse;
}

.vault-config td {
  padding: 0.4rem 0.8rem;
  border-bottom: 1px solid #333;
}

.vault-config .key {
  color: #4fc3f7;
  font-family: monospace;
  font-weight: bold;
  width: 40%;
}

.vault-config .secret {
  color: #ff9800;
  font-family: monospace;
}

.vault-note {
  color: #4caf50;
  font-size: 0.85rem;
  margin-top: 1rem;
}

.vault-error {
  color: #ff9800;
}

.vault-loading {
  color: #888;
}

.build-info {
  color: #666;
  font-size: 0.85rem;
  margin-top: 2rem;
}
</style>
