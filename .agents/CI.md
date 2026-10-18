# Continuous Integration (CI) Guidelines for Nas2Cloud SmartCam

---

## ⚙️ Environment & CI Context

* **GITHUB_USERNAME**: `thehavays`
* **REPOSITORY**: `nas2cloud-smartcam`
* **STACK**: Docker, Alpine Linux, Samba, Bash, Node.js, FFmpeg, Rclone
* **CI_STRATEGY**: Mandatory local verification gates and automated GitHub Actions PR checks

---

## 🎯 CI Philosophy & Purpose

Continuous Integration ensures that all code integrated into `dev` and `main`:
1. **Passes Script Syntax & Linting**: Shell scripts (`sync.sh`, `motion_clip.sh`, `entrypoint.sh`) and Node.js files compile without syntax errors.
2. **Builds Cleanly**: Docker image builds successfully across target architectures (`amd64` and `arm64`).
3. **Maintains Diff Hygiene**: No temporary video files, credentials, or stray debug scripts are committed.

---

## 🚦 Mandatory Local Verification Gates

Before opening a Pull Request or pushing changes to remote, run these gates in order:

### 1. Shell Script Syntax Check
Verify that all bash/sh scripts are free of syntax errors:
```bash
sh -n sync.sh
sh -n motion_clip.sh
sh -n entrypoint.sh
```
* **Acceptance Criteria**: Exit code 0, no syntax warnings.

### 2. Node.js Auth Server Syntax Check
Verify that the Express OAuth server syntax is valid:
```bash
node --check auth-server/server.js
```
* **Acceptance Criteria**: Exit code 0.

### 3. Docker Image Build Verification
Verify that the Dockerfile builds successfully:
```bash
docker build -t nas2cloud-smartcam:test .
```
* **Acceptance Criteria**: Clean compilation, exit code 0.

### 4. Diff Hygiene & Cleanliness
```bash
git status
git diff
```
* **Acceptance Criteria**:
  - No secrets (`.env`, `rclone.conf`, client secrets) tracked.
  - No recordings (`./data/*.mp4`) or log dumps staged.
  - Working tree is clean and scoped.

---

## 🤖 Automated CI Workflow (`pr-verification.yml`)

The repository runs an automated GitHub Action on every Pull Request targeting `dev` and `main`:
* **Workflow File**: [.github/workflows/pr-verification.yml](../.github/workflows/pr-verification.yml)
* **Action Steps**:
  1. Checks out repository code.
  2. Sets up Docker Buildx.
  3. Executes a test container build with caching.
* **Gate Requirement**: PRs cannot be merged until `verify-build` passes with green status.
