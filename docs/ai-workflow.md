# AI 自動實作流程（Issue → PR）

這個專案支援「AI 讀取 GitHub Issue → 自動實作 → 開 PR」的工作流程。  
你只需要建立 issue 並加上 `ai-task` label，Claude 就會接手實作並開 PR 等待你 review。

## 快速開始

1. **建立 issue**：使用 issue template（AI 功能需求 或 AI Bug 修復）
2. **加上 label**：對 issue 加上 `ai-task` label
3. **等待 Claude 實作**：在 issue 頁面可以看到即時進度 checkbox
4. **Review PR**：Claude 開好 PR 後，review 並 merge

就這樣。

## 完整流程圖

```
你建立 issue + 加上 "ai-task" label
          │
          ▼
claude-implement.yml 自動觸發
          │
          ▼
Claude 讀取 issue 內容
          │
          ▼
建立 branch（claude/issue-N-描述）
          │
          ▼
實作變更 → npm run build 驗證
          │
          ├─ 若 issue 太模糊或無法處理 → 在 issue 留言說明，結束
          │
          ▼
push + 開 PR（描述用繁體中文）
          │
          ▼
ci.yml 自動驗證（type check + build）
          │
          ▼
你 review + merge PR
          │
          ▼
cd-dev.yml → Docker build → 部署到 dev namespace
```

## Issue 撰寫技巧

Claude 的實作品質取決於 issue 的描述品質。

**好的 issue 範例：**
```
標題：在首頁加上環境 badge

描述：
在 HelloWorld.vue 的頁面頂部加上一個顯示目前環境的 badge。
- 讀取 import.meta.env.MODE 取得環境名稱（development / production）
- 樣式：圓角 badge，dev 顯示綠色，production 顯示藍色，白色文字
- 位置：現有標題上方

驗收條件：
- npm run build 成功
- 頁面上可以看到環境 badge
```

**不好的 issue 範例：**
```
標題：加個 badge

描述：想要知道現在是哪個環境
```

## 注意事項

### AI 的能力邊界

Claude 適合處理：
- 前端 UI 變更（Vue 元件、樣式）
- 文件更新（docs/）
- 小型功能新增（單一元件或少數檔案）
- Bug 修復（有明確錯誤描述）

Claude **不適合**處理：
- 需要大量架構變更的功能
- 涉及 secrets 或安全設定
- 需要溝通才能釐清需求的模糊需求
- Helm chart 或 ArgoCD 設定變更（需手動或用 `@claude` 詢問）

### 若 Claude 說無法處理

Claude 會在 issue 留言說明原因。你可以：
1. 補充更詳細的描述，重新加上 `ai-task` label（remove 再 add）
2. 自己實作，或用 `@claude` 在 PR 上請求協助

### AI 建立的 PR 如何辨識

- Branch 名稱以 `claude/` 開頭（例如 `claude/issue-5-add-env-badge`）
- Commit 作者為 `claude[bot]`

## 與現有 `@claude` 功能的差別

| | `ai-task` label | `@claude` 提及 |
|---|---|---|
| **觸發方式** | 對 issue 加 label | 在 issue/PR 留言 `@claude xxx` |
| **用途** | 完整實作一個需求 | 問問題、小修改、code review |
| **結果** | 開一個完整的 PR | 直接在當前 PR push commit 或留言回答 |
| **適合時機** | 你想讓 AI 從頭做一件事 | 你已有 PR，想要 AI 協助改進 |

## 相關檔案

- Workflow：`.github/workflows/claude-implement.yml`
- Issue Templates：`.github/ISSUE_TEMPLATE/ai-feature.yml`、`ai-bugfix.yml`
- AI 規則：`CLAUDE.md`（AI 自動實作模式章節）
