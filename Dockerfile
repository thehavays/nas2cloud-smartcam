FROM dperson/samba

# Install required packages (Node.js, npm, curl, unzip, ffmpeg, tzdata)
RUN apk add --no-cache nodejs npm curl unzip ffmpeg tzdata

# Install Rclone (Multi-arch support: amd64 / arm64 / arm-v7)
RUN ARCH=$(uname -m) && \
    case "$ARCH" in \
        x86_64)  RCLONE_ARCH="amd64" ;; \
        aarch64) RCLONE_ARCH="arm64" ;; \
        armv7l)  RCLONE_ARCH="arm-v7" ;; \
        *)       RCLONE_ARCH="amd64" ;; \
    esac && \
    curl -O "https://downloads.rclone.org/rclone-current-linux-${RCLONE_ARCH}.zip" && \
    unzip "rclone-current-linux-${RCLONE_ARCH}.zip" && \
    cd rclone-*-linux-${RCLONE_ARCH} && \
    cp rclone /usr/bin/ && \
    chown root:root /usr/bin/rclone && \
    chmod 755 /usr/bin/rclone && \
    cd .. && \
    rm -rf rclone-*

# Setup Auth Server
WORKDIR /app
COPY auth-server/package*.json ./
RUN npm install
COPY auth-server/server.js .

# Copy Sync Script
COPY sync.sh /app/sync.sh
RUN chmod +x /app/sync.sh

# Copy Motion Detection Script
COPY motion_clip.sh /app/motion_clip.sh
RUN chmod +x /app/motion_clip.sh

# Copy Entrypoint Script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose ports: 8080 (Auth Server), 139 445 (Samba)
EXPOSE 8080 139 445

ENTRYPOINT ["/app/entrypoint.sh"]
