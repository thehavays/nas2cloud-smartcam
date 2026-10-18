# Continuous Deployment (CD) Guidelines for Nas2Cloud SmartCam

---

## ⚙️ Environment & CD Context

* **HOSTING_PLATFORM**: GitHub Container Registry (GHCR)
* **IMAGE_NAME**: `ghcr.io/thehavays/nas2cloud-smartcam`
* **GITHUB_USERNAME**: `thehavays`
* **REPOSITORY**: `nas2cloud-smartcam`
* **DEPLOYMENT_TYPE**: Automated container image build and publish via GitHub Actions
* **TARGET_ARCHITECTURES**: `linux/amd64`, `linux/arm64`

---

## 🌐 Delivery & Distribution Architecture

Nas2Cloud SmartCam is distributed as a multi-architecture Docker container image published to GHCR. Users pull and run the container locally on Linux, macOS (Docker Desktop), or Windows (Docker Desktop):

1. **Tag Push**: Release triggers automatically upon pushing a semantic version tag (e.g., `v1.2.0`).
2. **Buildx Multi-Arch Build**: GitHub Actions builds container images natively for Intel/AMD (`amd64`) and Apple Silicon / ARM (`arm64`) using QEMU.
3. **Registry Publication**: Images are tagged with semantic versions (`1.2.0`, `1.2`, `1`) and `latest`, then published to GHCR.

---

## 🌿 Environment & Branch Mappings

| Stage | Source Branch / Ref | Deployment Trigger | Output Target | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Production** | Git Tag (`v*`) on `main` | Tag push | `ghcr.io/thehavays/nas2cloud-smartcam:<version>` & `:latest` | Stable end-user container release |
| **Integration** | `dev` branch | PR merge to `dev` | Local builds (`docker compose up -d --build`) | Integration and feature testing |
| **PR Validation** | Feature branches (`feat/*`, `fix/*`) | PR opened / updated | Ephemeral Buildx cache | Verification prior to merge |

---

## 🚀 Production Release Workflow

1. **Staging Verification**: Ensure all features and fixes are thoroughly tested on `dev`.
2. **Open Release PR**:
   - Ask for user confirmation.
   - Open Pull Request from `dev` to `main` with title `chore: release vX.Y.Z`.
3. **Merge Release PR**:
   - Ask for user confirmation after CI checks pass.
   - Merge the PR to `main`.
4. **Create & Push Semantic Tag**:
   ```bash
   git checkout main
   git pull origin main
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```
5. **Monitor Publish Workflow**:
   Observe [.github/workflows/docker-publish.yml](../.github/workflows/docker-publish.yml) on GitHub Actions until the image is published to GHCR.
