# Security fixes applied

## 已修正項目

- 前端
  - 移除 `eval` 與危險的 `innerHTML` 使用，改為 `textContent`。
  - 修正 `setTimeout` 以避免字串執行，對使用者輸入進行解析與邊界檢查。
  - 移除硬編碼的 API key / DB URL（改以 secrets 或後端管理）。
  - 移除易受 ReDoS 的危險正則，改用安全的輸入驗證。

- Nginx
  - 新增 `Content-Security-Policy`、`Strict-Transport-Security`、`X-Frame-Options`、`X-Content-Type-Options`、更嚴格的 `Referrer-Policy`。
  - 關閉 `server_tokens` 以隱藏版本資訊。

- Docker
  - 將容器配置為在非 root 使用者（`nginx`）下執行，建立並 chown 必要目錄以降低權限風險。

- CI / Workflow
  - 收緊 workflow 全域權限（只保留 `contents: read`）。
  - 鎖定 Trivy 與 Dependency-Check action 至 major tag（避免 `master`/`main` 浮動 refs）。
  - 新增 Semgrep 與 Trivy 的 SARIF 檢查步驟：若發現 high/critical 或 Semgrep finding，相關 job 會失敗並阻止後續部署。

## 剩餘風險與建議

- Secrets 管理：請把所有敏感值放入 GitHub Secrets 或秘密管理系統，前端勿硬編碼敏感資料。
- Action pinning：若要更嚴格，建議把所有 `uses:` 鎖定到具體 release tag（例如 `@v1.2.3`）。我已移除明顯的 `master`/`main` 浮動引用。
- 自動化政策：建議在 PR gate 中加入 SAST/SCA/Trivy 的 fail-on-severity 規則，並定期執行依賴更新掃描（Dependabot）。
- 二進位掃描：在發佈前對映像使用 Trivy 或其他掃描工具並納入 SBOM（若適用）。
- 定期審計：安排定期安全掃描與 code-review，並在發現重大風險時自動封鎖合併。

## 本地測試

建議在有 Docker daemon 的主機執行測試腳本：

```bash
chmod +x scripts/test_local.sh
./scripts/test_local.sh
```

腳本會：
- 建置 Docker 映像
- 啟動容器並對外綁定 8080
- 擷取回應標頭並檢查常見安全標頭
- 停止並移除容器 & 映像

---

如需，我可以：
- 進一步替所有 action 查詢並鎖定到具體 minor/patch release（需網路查詢）。
- 把這些變更提交成一個 commit 並開 PR（若你要我幫你在 repo 推送並建立 PR）。
