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
  - 已更新 `Dockerfile`：移除 `perl` 變體並鎖定為較新的 `nginx:1.26.6-alpine3.18`，建置時加入 `apk upgrade` 以嘗試取得最新修補，建議後續以 digest pin 並定期更新基底映像以減少 CVE。

- CI / Workflow
  - 收緊 workflow 全域權限（只保留 `contents: read`）。
  - 鎖定 Trivy 與 Dependency-Check action 至 major tag（避免 `master`/`main` 浮動 refs）。已將 Dependency-Check action 鎖定為 `@v3`（建議將來鎖定到具體 release 或 SHA）。
  - 新增 Semgrep 與 Trivy 的 SARIF 檢查步驟：若發現 high/critical 或 Semgrep finding，相關 job 會失敗並阻止後續部署。
  - 新增 Dependabot 設定以每週自動檢查 Docker 基底映像與其它依賴的更新，減少已知 CVE。
  - 新增 CI job `base-image-scan` 以定期掃描並上傳 base image 的 Trivy SARIF（若發現 HIGH/CRITICAL 將使 job 失敗以阻止不安全的映像被使用），並把 `trivy-results.sarif` 與 `trivy-base.sarif` 上傳為 artifact 以便下載與分析。
  - 將 `Dockerfile` 的預設 base image 改為 `nginx:1.26.6`（Debian-based），並在建置時加入跨發行版的系統套件升級步驟（會根據 `apk` 或 `apt-get` 判斷執行），以降低 Alpine 特有套件（musl、busybox）及其 CVE 暴露。
  - 移除不必要的工具（例如 `curl`）在建置階段若檢測到會自動移除，以減少因 `curl/libcurl` 的已知漏洞（如 HTTP/2 push headers memory-leak）所帶來的風險。若你的應用需使用 `curl`，請告知以便我改成升級或 pin 到已修補版本的策略。
  - 已加入 Dockerfile 中針對 **libxml2、libxslt、expat、xz、perl、openssl** 的升級嘗試步驟（會依 package manager 自動執行），以嘗試降低這些套件造成的 HIGH/CRITICAL 風險；但最可靠的解法仍是使用已修補的 base image（或 pin 至 digest），我會在取得 `trivy-base.sarif` 後給出具體建議與可合併的 PR。

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

## 如發現已洩漏（重要操作指南）

1. **立即輪替受影響的憑證/令牌**（API keys、GCP/AWS 憑證、資料庫密碼、OAuth client secrets 等）。不要只從 repo 刪除：必須在服務端撤銷並重新產生。
2. **清理 Git 歷史（如果憑證曾出現在 commit 歷史）**：使用 `git filter-repo` 或 BFG 移除敏感檔案/內容，並在清理後強制推送到遠端（注意會改寫歷史，需團隊協調）。範例：

```bash
# 使用 git-filter-repo (建議)
git clone --mirror git@github.com:OWNER/REPO.git
cd REPO.git
git filter-repo --path-glob 'path/to/file/with/secret' --invert-paths
git push --force
```

或用 BFG：
```bash
bfg --delete-files YOUR_SECRET_FILE
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force
```

3. **通知並紀錄**：建立事件紀錄，通知受影響團隊與服務擁有者，根據你的資安政策啟動 incident response。
4. **把掃描結果放到安全位置**：將 gitleaks/Trivy/Semgrep 的報告上傳到安全的 artifact 或 CI 的保留位置，避免在公共討論中公開敏感細節。
5. **加強 pipeline**：確保 `secret-scan` job 在 PR 階段也會運行並阻止含有敏感內容的 PR 合併（現在已新增 JSON 檢查步驟）。

如果你要我代為處理歷史清理（會改寫 Git 歷史），請先確認你有權在此 repo 強制推送，並提供一個分支策略或允許我開 PR。我可以：
- 幫你產生一個清理步驟腳本並說明操作風險。 
- 或在 PR 中提供重寫歷史的腳本與步驟，交由你手動執行。
