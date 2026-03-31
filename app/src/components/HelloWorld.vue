<script setup lang="ts">
import { ref } from 'vue'

const count = ref(0)
const buildTime = __BUILD_TIME__
</script>

<template>
  <div class="container">
    <h1>🚀 GitOps Practice App</h1>
    <p class="subtitle">Vue 3 + Vite + Docker + Helm + Argo CD</p>

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
      </ul>
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

.build-info {
  color: #666;
  font-size: 0.85rem;
  margin-top: 2rem;
}
</style>
