# Nas2Cloud SmartCam (Server) — Agent & Developer Guide

This document is the primary onboarding and operational guide for AI agents and developers working in the `nas2cloud-smartcam` repository.

---

## 📖 Project Overview

**Nas2Cloud SmartCam** is an automated backup and processing pipeline for NAS-capable security cameras (Xiaomi, Reolink, TP-Link Tapo, Eufy, Amcrest, etc.). It acts as a local NVR (Network Video Recorder) that stores video files locally and syncs them to Google Drive for free, bypassing expensive cloud subscriptions.

### 🛠️ Core Technology Stack
- **Base Image**: `dperson/samba` (Alpine Linux)
- **Languages / Runtimes**: Node.js 20+ (OAuth server), Bash / POSIX Shell (sync & motion detection)
- **Video Engine**: FFmpeg & FFprobe (scene-change analysis & clip cutting)
- **Cloud Sync**: Rclone (Google Drive synchronization daemon)
- **NAS Protocol**: Samba SMB (`netbios name = camnas`, share `cam_storage`)
- **Containerization**: Docker, Docker Compose (Linux, macOS, Windows configurations)

---

## 📁 Repository Structure

```
nas2cloud-smartcam/
├── .agents/                 # AI agent guidelines and architecture docs
│   ├── AGENTS.md            # Detailed subproject onboarding guide
│   ├── GIT_WORKFLOW.md      # Protected branching, gates & GitHub MCP standards
│   ├── CI.md                # Continuous Integration verification gates
│   └── CD.md                # Continuous Deployment & GHCR image publishing
├── .github/
│   ├── workflows/
│   │   ├── pr-verification.yml # Automated Docker build test on PRs
│   │   └── docker-publish.yml  # Multi-arch GHCR image release on tags
│   ├── ISSUE_TEMPLATE/      # GitHub Issue forms (bug, feature)
│   └── pull_request_template.md # PR quality checklist
├── auth-server/             # Node.js OAuth Express server (port 8080)
│   ├── package.json
│   └── server.js
├── data/                    # Local storage mounted to /mnt/data (ignored in git)
├── rclone/                  # Rclone configs and OAuth tokens (ignored in git)
├── .editorconfig            # Coding style & formatting standards
├── .env.example             # Example environment configuration (zero secrets)
├── .gitignore               # Ignored recordings, tokens, and node_modules
├── Dockerfile               # Multi-arch (amd64, arm64) Alpine container
├── docker-compose-linux.yml # Host networking setup for Linux
├── docker-compose-mac.yml   # Port exposure & dynamic timezone for macOS
├── docker-compose-windows.yml # Port exposure setup for Windows
├── entrypoint.sh            # Boots Auth Server, Sync daemon, and Samba
├── motion_clip.sh           # FFmpeg motion detection & sub-clip extraction
├── sync.sh                  # Periodic Rclone sync & retention cleaner
├── LICENSE                  # MIT License
└── README.md                # Complete user guide and setup instructions
```

---

## ⚡ Canonical Commands

Always use the following commands for development, operational tasks, and verification:

| Action | Command | Purpose |
| :--- | :--- | :--- |
| **Start (macOS)** | `docker compose -f docker-compose-mac.yml up -d` | Starts container with explicit port mappings |
| **Start (Linux)** | `docker compose -f docker-compose-linux.yml up -d` | Starts container with host networking |
| **Start (Windows)** | `docker compose -f docker-compose-windows.yml up -d` | Starts container on Windows Docker Desktop |
| **Rebuild Container** | `docker compose -f <compose-file> up -d --build` | Rebuilds Docker image and restarts service |
| **Check Live Logs** | `docker logs -f nas2cloud-smartcam` | Views sync and motion detection logs |
| **Inspect SMB Status** | `docker exec nas2cloud-smartcam smbstatus` | Verifies active camera connections & locks |
| **Lint Shell Scripts** | `sh -n sync.sh motion_clip.sh entrypoint.sh` | Verifies shell script syntax |
| **Lint Auth Server** | `node --check auth-server/server.js` | Checks Node.js Express server syntax |

---

## 🌿 Git & Version Control Workflow

For complete version control guidelines, see [.agents/GIT_WORKFLOW.md](./.agents/GIT_WORKFLOW.md).

### Summary Rules:
1. **Protected Branches**: Direct pushes to `main` and `dev` are strictly forbidden.
2. **Branch Roles**:
   - `dev`: Primary integration branch. All feature branches (`feat/*`, `fix/*`, `chore/*`) target `dev`.
   - `main`: Production branch. Updated only via Release Pull Requests from `dev`.
3. **MANDATORY User Confirmation Gates**:
   - **Gate 1**: ALWAYS ask user approval before opening a PR (`create_pull_request`).
   - **Gate 2**: ALWAYS ask user approval before merging a PR (`merge_pull_request`).
4. **GitHub MCP Server Integration**: All GitHub actions (Issues, PRs, comments) are executed via **GitHub MCP Server** tools (`issue_write`, `create_pull_request`, `merge_pull_request`), avoiding CLI token conflicts.
5. **Issue Linking**:
   - On `dev` PRs: use `ref #<issue_number>` (NEVER use `closes #...`).
   - On `main` Release PRs: use `closes #<issue_number>` to close issues upon production release.

---

## 🔄 CI/CD Guidelines
- **CI**: See [.agents/CI.md](./.agents/CI.md) for quality gates and local verification steps.
- **CD**: See [.agents/CD.md](./.agents/CD.md) for GitHub Actions GHCR image publishing.
