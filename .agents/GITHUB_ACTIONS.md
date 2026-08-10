# GitHub Actions & CI/CD Guidelines for Nas2Cloud SmartCam

---

## ⚙️ Environment Variables (Context)
* **GITHUB_USERNAME**: `thehavays`
* **GITHUB_PROJECT_NAME**: `nas2cloud-smartcam`
* **CONTAINER_REGISTRY**: `ghcr.io`

---

This document details the GitHub Actions CI/CD workflows, build automation, container publishing guidelines, and rules for creating or modifying workflow files.

---

## 🚀 Active Workflows Summary

Currently configured workflows are stored under [`.github/workflows/`](../.github/workflows):

### 1. Docker Image CI (`docker-publish.yml`)
* **File**: [`.github/workflows/docker-publish.yml`](../.github/workflows/docker-publish.yml)
* **Trigger**: Automatically runs **only when a release tag is pushed** (`tags: [ "v*" ]`). It does **not** publish on regular branch pushes.
* **Actions Performed**:
  1. Checks out the repository code (`actions/checkout@v4`).
  2. Logs into GitHub Container Registry (`ghcr.io`) using `${{ secrets.GITHUB_TOKEN }}`.
  3. Generates metadata and tags (`vX.Y.Z` semver and `latest`).
  4. Builds and pushes the Docker image to `ghcr.io/thehavays/nas2cloud-smartcam`.

---

## 🛠️ Guidelines for Adding & Modifying Workflows

### 1. Workflow File Location
All GitHub Actions workflow definition files **must** be placed in:
```text
.github/workflows/<workflow-name>.yml
```

### 2. Branch Triggering Rules
* **Pull Request Validation (CI)**:
  * Tests, lint checks, or build verifications trigger on `pull_request` targeting `dev` and `main`.
  * **Best Practices for PR CI Trigger**:
    * Include `types: [ opened, synchronize, reopened ]` to ensure PRs are re-verified on updates or re-openings.
    * Use `paths-ignore` to skip running workflows when only documentation or agent rules change.
    * Use `concurrency` with `cancel-in-progress: true` to auto-cancel outdated workflow runs when new commits are pushed to the same PR (saves runner minutes).
    ```yaml
    on:
      pull_request:
        types: [ opened, synchronize, reopened ]
        branches: [ "dev", "main" ]
        paths-ignore:
          - '**.md'
          - '.agents/**'

    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true
    ```
* **Release & Image Deployment (CD)**:
  * Container publishing and release builds must trigger **only on tag creation** (`v*`):
    ```yaml
    on:
      push:
        tags: [ "v*" ]
    ```

### 3. Permissions & Security
* Always restrict job permissions to minimum required privileges using explicit `permissions` blocks:
  ```yaml
  permissions:
    contents: read
    packages: write
  ```
* Never hardcode sensitive secrets in workflow files; rely on `${{ secrets.GITHUB_TOKEN }}` or repository secrets (`${{ secrets.MY_SECRET }}`).

### 4. Recommended Workflow Template (PR Verification)
When creating a new PR validation workflow:
```yaml
name: PR Verification

on:
  pull_request:
    types: [ opened, synchronize, reopened ]
    branches: [ "dev", "main" ]
    paths-ignore:
      - '**.md'
      - '.agents/**'

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  verify-build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Verify Docker Build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false

---

## 💡 CI/CD Best Practices

1. **Automate PR Verification (Fail Fast)**:
   * Every Pull Request targeting `dev` or `main` must trigger automated build verification (`push: false`) to catch broken Dockerfiles or syntax errors before merging.
   * Run quick checks (e.g. ShellCheck for bash scripts or Node syntax checks) before expensive Docker build steps.

2. **Use GitHub Actions Caching**:
   * Speed up workflow execution by leveraging build layer caching for Docker and dependency caching for npm/Node.js:
     ```yaml
     cache-from: type=gha
     cache-to: type=gha,mode=max
     ```

3. **Enforce Least-Privilege Security**:
   * Set job permissions explicitly (`contents: read` for checkout, `packages: write` only when pushing images).
   * Use `${{ secrets.GITHUB_TOKEN }}` instead of long-lived Personal Access Tokens (PATs) whenever possible.
   * Pin GitHub Actions to verified major versions (e.g., `actions/checkout@v4`).

4. **Strict Separation of CI and CD**:
   * **CI (Continuous Integration)**: Triggers on PRs to test and validate changes (`push: false`).
   * **CD (Continuous Deployment)**: Triggers **only when a Git release tag (`v*`) is pushed**, ensuring no incomplete code is published to container registries.

5. **Deterministic Builds**:
   * Ensure Docker builds and scripts are reproducible by locking base image versions or dependencies.
```
