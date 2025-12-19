# 使用可配置的 base image，建議在 PR/CI 中以 digest pin 或具體 tag 更新
ARG BASE_IMAGE=nginx:1.26.6-alpine3.18
# 若你有穩定的 digest，可把 BASE_IMAGE 改為帶有 sha256 的鏡像（更安全）
FROM ${BASE_IMAGE}

# 在建置時更新基底套件以嘗試獲得最新修補（建議仍以新映像為主）
RUN apk update && apk upgrade --no-cache

# 維護者資訊
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/YOUR_REPO"
LABEL org.opencontainers.image.description="井字遊戲 - 靜態網頁應用"
LABEL org.opencontainers.image.licenses="MIT"

# 移除預設的 Nginx 網頁
RUN rm -rf /usr/share/nginx/html/*

# 複製靜態檔案到 Nginx 目錄
COPY app/ /usr/share/nginx/html/

# 建立自訂的 Nginx 配置（監聽 8080 端口以支援非 root 用戶）
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 修改 Nginx 配置以支援非 root 用戶運行
RUN sed -i 's/listen\s*80;/listen 8080;/g' /etc/nginx/conf.d/default.conf && \
    sed -i 's/listen\s*\[::\]:80;/listen [::]:8080;/g' /etc/nginx/conf.d/default.conf && \
    sed -i "s,root /usr/share/nginx/html;,root /usr/share/nginx/html;," /etc/nginx/conf.d/default.conf && \
    mkdir -p /tmp/proxy_temp /tmp/client_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx /tmp || true

# 暴露 8080 端口（非特權端口）
EXPOSE 8080

# 以容器內預設的 nginx 使用者執行，避免使用 root
USER nginx

# 啟動 Nginx
CMD ["nginx", "-g", "daemon off;"]