# Git & GitHub Workflow Guidelines for Nas2Cloud SmartCam

---

## ⚙️ Environment Variables (Context)

* **GITHUB_USERNAME**: `thehavays`
* **GITHUB_PROJECT_NAME**: `Nas2Cloud SmartCam`

---

This document details the version control and GitHub conventions used in this project. Follow these guidelines to maintain a clean history and avoid build or deployment issues.

---

## 🌿 Branching Strategy

We use a standard branching structure with `dev` as the main integration branch. Both `main` and `dev` are **protected branches**:

1. **`dev` (Development Branch)**:
   * This is the default branch for active development.
   * All feature branches, bug fixes, and chores should be branched from `dev` and merged back into `dev`.
2. **`main` (Production Branch)**:
   * Holds the stable production release code.
   * Periodically, `dev` is merged into `main` via a Pull Request.

### 🛡️ Branch Protection Rules

Direct pushes to `main` and `dev` are strictly forbidden. Changes can only be merged via Pull Requests.

* **Review Requirements**: All PRs must have at least **one approved review** from a reviewer before they can be merged.
* **Admin Override**: A PR can be merged without reviews *only* if merged by an administrator (e.g., using the `--admin` bypass flag in the GitHub CLI).

### Working on a Feature, Bug Fix, or Change

* **Issue Pre-requisite**: Before committing any changes, verify if a GitHub Issue exists for the work. **If an issue does NOT exist, create one first**:

  ```bash
  GITHUB_TOKEN= gh issue create --assignee <GITHUB_USERNAME> --project <GITHUB_PROJECT_NAME> --title "<summary>" --body "<description>"
  ```

* **Branch Creation**: Create and switch to a branch linked to the issue:

  ```bash
  git checkout dev
  git pull
  GITHUB_TOKEN= gh issue develop <issue_number> --base dev --checkout
  ```

---

## 🔑 GitHub CLI (`gh`) & GITHUB_TOKEN Conflict

There is a conflict with the `GITHUB_TOKEN` environment variable in the shell environment.

* **Problem**: The shell env has an invalid `GITHUB_TOKEN` set, which overrides your local authentication keyring.
* **Rule**: When executing **any** `gh` CLI commands, you **must** prefix the command with `GITHUB_TOKEN=` to bypass the invalid environment token and use the working local credential manager.
  * *Correct*: `GITHUB_TOKEN= gh pr create ...`
  * *Incorrect*: `gh pr create ...`

---

## 💬 Issue & PR Creation Conventions

* **Assignee & Project Rules**: When creating a new Issue or Pull Request, **always** assign it to `GITHUB_USERNAME` and link it to `GITHUB_PROJECT_NAME`:
  * **Creating an Issue**:

    ```bash
    GITHUB_TOKEN= gh issue create --assignee <GITHUB_USERNAME> --project <GITHUB_PROJECT_NAME> --title "..." --body "..."
    ```

  * **Creating a PR**:

    ```bash
    GITHUB_TOKEN= gh pr create --assignee <GITHUB_USERNAME> --project <GITHUB_PROJECT_NAME> --base dev --title "..." --body "..."
    ```

* **Commit messages**: Use semantic prefix naming conventions:
  * `feat: ...` for new features (e.g. `feat: support pre-configuring Google Cloud OAuth credentials via env (closes #23)`).
  * `fix: ...` for bug fixes.
  * `chore: ...` for structural or auxiliary updates.
* **PR Target**: Always direct your pull request to the `dev` branch.
* **Syncing to Main**: Once features are stable in `dev`, open a PR from `dev` to `main` (`GITHUB_TOKEN= gh pr create --assignee <GITHUB_USERNAME> --project <GITHUB_PROJECT_NAME> --base main --head dev`).

---

## 🏷️ Tagging & Releases

When asked to create a tag/release:

1. **Checkout the main branch** and pull the latest changes:

   ```bash
   git checkout main
   git pull
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

---

## 💡 Git & GitHub Best Practices

1. **Keep Feature Branches Up to Date**:
   * Regularly pull updates from `dev` into your feature branch before creating a PR to resolve merge conflicts early:

     ```bash
     git fetch origin
     git rebase origin/dev
     ```

2. **Automatic Issue Linking**:
   * Always include closing keywords in commit messages or PR descriptions (e.g., `closes #23`, `resolves #45`). This links the PR to the issue on GitHub and automatically closes the issue when merged.
3. **Branch Hygiene & Cleanup**:
   * Clean up merged feature branches locally and remotely to avoid repository bloat:

     ```bash
     GITHUB_TOKEN= gh pr merge <pr_number> --merge -d
     ```

4. **Draft Pull Requests for Early Feedback**:
   * If a feature is a work in progress and you want early code review or automated testing, create a draft PR:

     ```bash
     GITHUB_TOKEN= gh pr create --draft --base dev
     ```
