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
* **Admin Override**: A PR can be merged without reviews *only* if merged by an administrator (e.g., using `--admin` flag in the GitHub CLI).

### 🛑 User Confirmation Gates (MANDATORY)

To prevent unwanted changes, maintain strict quality control, and ensure implementation matches user expectations:
1. **Gate 1 — Before Opening a Pull Request**:
   * The agent **MUST explicitly ask the user for confirmation** before running `gh pr create` or using GitHub MCP `create_pull_request`.
   * **Rationale**: The user may request additional modifications, want to review the diff/files first, or adjust scope before a PR is opened.
2. **Gate 2 — Before Merging a Pull Request**:
   * Even when CI checks succeed with green status, the agent **MUST explicitly ask the user for confirmation** before running `gh pr merge` or using GitHub MCP `merge_pull_request`.
   * **Rationale**: The user must review the build/preview behavior and give explicit approval before integrating changes into `dev` or releasing to `main`.

---

## 🔑 GitHub CLI (`gh`) & GITHUB_TOKEN Conflict

There is a conflict with the `GITHUB_TOKEN` environment variable in the shell environment.

* **Problem**: The shell env has an invalid `GITHUB_TOKEN` set, which overrides your local authentication keyring.
* **Rule**: When executing **any** `gh` CLI commands, you **must** prefix the command with `GITHUB_TOKEN=` to bypass the invalid environment token and use the working local credential manager.
  * *Correct*: `GITHUB_TOKEN= gh pr create ...`
  * *Incorrect*: `gh pr create ...`

---

## 📋 Issue Pre-requisite & Closure Policy (MANDATORY)

Before committing changes or starting work:
1. **Verify Existing Issues**: Check if an open GitHub Issue exists for the work:
   ```bash
   GITHUB_TOKEN= gh issue list --assignee thehavays
   ```
2. **Create Issue First**: If no issue exists, create one and assign it:
   ```bash
   GITHUB_TOKEN= gh issue create --assignee thehavays --title "<summary>" --body "<description>"
   ```
3. **Branch Creation**: Create and switch to a branch linked to the issue:
   ```bash
   git checkout dev
   git pull origin dev
   GITHUB_TOKEN= gh issue develop <issue_number> --base dev --checkout
   ```
4. **Issue Linking Policy**:
   * **Feature PRs (targeting `dev`)**: Use `ref #<issue_number>` in PR description. **DO NOT** use `closes #...` on `dev` PRs.
   * **Release PRs (targeting `main`)**: Use `closes #<issue_number>` in the Release PR description so issues are closed ONLY when promoted to production.

---

## 💬 Commit & PR Conventions

* **Commit messages**: Use Conventional Commits naming conventions:
  * `feat: ...` for new features (e.g. `feat: support pre-configuring Google Cloud OAuth credentials via env (ref #23)`).
  * `fix: ...` for bug fixes.
  * `chore: ...` for structural, dependency, or auxiliary updates.
  * `docs: ...` for documentation updates.
* **PR Target**: Always direct feature pull requests to the `dev` branch.
* **Pre-flight Check**: Always run script syntax checks (`sh -n sync.sh motion_clip.sh entrypoint.sh`) and Docker build check before requesting PR approval.

---

## 🏷️ Tagging & Releases

When asked to create a tag/release:

1. **Checkout the main branch** and pull the latest changes:
   ```bash
   git checkout main
   git pull origin main
   ```
2. **Create the tag locally** (use semantic versioning, e.g., `v1.0.1`):
   ```bash
   git tag -a v<version> -m "Release v<version>"
   ```
3. **Push the tag to GitHub**:
   ```bash
   git push origin v<version>
   ```
4. **Create a GitHub release** from the tag:
   ```bash
   GITHUB_TOKEN= gh release create v<version> --title "Release v<version>" --generate-notes
   ```
