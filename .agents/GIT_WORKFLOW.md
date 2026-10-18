# Git & GitHub Workflow Guidelines for Nas2Cloud SmartCam

---

## ⚙️ Environment Variables (Context)

* **GITHUB_USERNAME**: `thehavays`
* **GITHUB_PROJECT_NAME**: `Nas2Cloud SmartCam`
* **REPOSITORY**: `nas2cloud-smartcam`
* **REMOTE_URL**: `https://github.com/thehavays/nas2cloud-smartcam.git`
* **INTEGRATION_BRANCH**: `dev`
* **PRODUCTION_BRANCH**: `main`

---

## 🌿 Branching Strategy

We use a standard two-tier branching structure with `dev` as the main integration branch. Both `main` and `dev` are **protected branches**:

1. **`dev` (Development Branch)**:
   * The default branch for active development.
   * All feature branches, bug fixes, and chores branch from `dev` and merge back into `dev`.
2. **`main` (Production Branch)**:
   * Holds the stable production release code.
   * Periodically, `dev` is merged into `main` via a Release Pull Request.

### 🛡️ Branch Protection Rules

* **Direct Pushes**: Direct pushes to `main` and `dev` are strictly forbidden. All changes must be delivered via Pull Requests.
* **Review Requirements**: All PRs must have at least **one approved review** from a reviewer before they can be merged.
* **Admin Override**: A PR can be merged without reviews *only* if merged by an administrator or repository owner.

### 🛑 User Confirmation Gates (MANDATORY)

To prevent unwanted changes, maintain strict quality control, and ensure implementation matches user expectations:
1. **Gate 1 — Before Opening a Pull Request**:
   * The agent **MUST explicitly ask the user for confirmation** before using GitHub MCP `create_pull_request`.
   * **Rationale**: The user may request additional modifications, want to review the diff/files first, or adjust scope before a PR is opened.
2. **Gate 2 — Before Merging a Pull Request**:
   * Even when CI checks succeed with green status, the agent **MUST explicitly ask the user for confirmation** before using GitHub MCP `merge_pull_request`.
   * **Rationale**: The user must review the build/preview behavior and give explicit approval before integrating changes into `dev` or releasing to `main`.

---

## 🤖 GitHub MCP Server Integration

All GitHub operations in this workspace are managed natively via the **GitHub MCP Server**. 
Do **NOT** use the `gh` CLI in terminal commands. Using GitHub MCP tools completely eliminates local shell `GITHUB_TOKEN` environment conflicts and provides authenticated, programmatic GitHub API access.

### MCP Tools Mapping:
| Operation | GitHub MCP Tool | Arguments / Example |
| :--- | :--- | :--- |
| **List Issues** | `list_issues` | `owner: "thehavays"`, `repo: "nas2cloud-smartcam"`, `state: "open"` |
| **Create Issue** | `issue_write` | `method: "create"`, `title`, `body`, `assignees: ["thehavays"]` |
| **Close Issue** | `issue_write` | `method: "update"`, `issue_number`, `state: "closed"`, `state_reason: "completed"` |
| **Add Comment** | `add_issue_comment` | `issue_number`, `body: "..."` |
| **Create PR** | `create_pull_request` | `base: "dev"`, `head: "<branch>"`, `title`, `body` |
| **Inspect PR** | `pull_request_read` | `method: "get"`, `pullNumber` |
| **Merge PR** | `merge_pull_request` | `pullNumber`, `merge_method: "merge"` |
| **List Releases** | `list_releases` | `owner: "thehavays"`, `repo: "nas2cloud-smartcam"` |

---

## 📋 Issue Pre-requisite & Branching Workflow (MANDATORY)

Before committing changes or starting work:
1. **Verify Existing Issues**: Call `list_issues` via GitHub MCP to check if an open issue exists.
2. **Create Issue First**: If no issue exists, call `issue_write` (method: `create`) with title, structured body, and `assignees: ["thehavays"]`.
3. **Branch Creation**: Create and switch to a branch linked to the issue:
   ```bash
   git checkout dev
   git pull origin dev
   git checkout -b <issue_number>-<type>-<short-description>
   ```
4. **Issue Linking Policy**:
   * **Feature PRs (targeting `dev`)**: Use `ref #<issue_number>` in PR description. **DO NOT** use `closes #...` on `dev` PRs.
   * **Release PRs (targeting `main`)**: Use `closes #<issue_number>` in the Release PR description so issues are closed upon production release, or close via `issue_write` after release.

---

## 💬 Commit & PR Conventions

* **Commit messages**: Use Conventional Commits naming conventions:
  * `feat: ...` for new features (e.g. `feat: support pre-configuring Google Cloud OAuth credentials via env (ref #23)`).
  * `fix: ...` for bug fixes.
  * `chore: ...` for structural, dependency, or auxiliary updates.
  * `docs: ...` for documentation updates.
* **PR Target**: Always direct feature pull requests to the `dev` branch.
* **Pre-flight Check**: Always run script syntax checks (`sh -n sync.sh motion_clip.sh entrypoint.sh`) and Docker build check before requesting PR approval.
* **PR Creation**: Call `create_pull_request` via GitHub MCP after User Confirmation Gate 1.
* **PR Merge**: Call `merge_pull_request` via GitHub MCP after User Confirmation Gate 2.

---

## 🏷️ Tagging & Releases

When creating a release:

1. **Checkout the main branch** and pull the latest changes:
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Create the tag locally** (use semantic versioning, e.g., `v1.1.0`):
   ```bash
   git tag -a v<version> -m "Release v<version> - <summary>"
   ```

3. **Push the tag to GitHub**:
   ```bash
   git push origin v<version>
   ```

4. **Automated Docker Publishing**:
   Pushing the `v*` tag automatically triggers the `.github/workflows/docker-publish.yml` GitHub Actions workflow, building multi-architecture Docker container images (`linux/amd64`, `linux/arm64`) and publishing them to the GitHub Container Registry (`ghcr.io/thehavays/nas2cloud-smartcam:<version>`).
