# Security Policy & Hardening Guide for `dotfiles`

This document explains how to publish your dotfiles safely and how to avoid leaking credentials or sensitive system details. It also includes a checklist you can run **before every push**.

---

## 1) Scope & threat model

Publishing dotfiles makes parts of your system configuration public. Risks include:
- Accidental leakage of **credentials** (tokens, API keys, passwords).
- Exposure of **personal data** (full name, email, hostnames, user paths).
- Revealing **machine-specific details** (IPs, network names, hardware serials).
- Allowing an attacker to **re-create your environment** to craft targeted attacks (phishing/social engineering).

This repo is designed to only contain **generic, portable configs**. Anything secret or machine‑specific should be **templated** or **ignored**.

---

## 2) Never commit these

Add these to `.gitignore` (already partly present), and **do not** stage them:

```bash
# Secrets / credentials
.ssh/
.gnupg/
.aws/
.azure/
.docker/config.json
.npmrc
.pypirc
.config/gh/hosts.yml
.config/rclone/
.config/gcloud/
.config/1Password/
.config/Bitwarden/
.config/protonmail/  # Bridge caches, tokens
.ly/                 # any login manager caches
.cache/
*.key
*.pem
*.p12
*.pfx
*.kdbx
*.age
*.gpg
*.asc

# OS / editor leftovers
*~
.DS_Store
Thumbs.db
__pycache__/
*.swp
*.swo

# Local machine backups
.dotfiles_backup_*/
```

> **Note:** Don’t commit **private** SSH or GPG keys. If you want to share your **public** keys, place only `*.pub` files in a dedicated folder and document their purpose.

---

## 3) Commonly overlooked leaks

- **Hostnames / usernames / home paths:** e.g. `applepie`, `/home/tim`. Prefer `$HOME` or `~` in configs. Use variables in scripts.
- **Absolute paths to personal folders:** use relative paths or `$XDG_*` variables where possible.
- **Tokens inside systemd user units:** move secrets into environment files outside the repo (`EnvironmentFile=`) and ignore those files.
- **Screenshots:** PNG typically has little EXIF, but **verify** no metadata or overlays leak information.

Check screenshots with:
```bash
exiftool -a -u -g1 screenshots/*.png
```

---

## 4) How to scan before pushing

### 4.1 Quick local grep (cheap & fast)
```bash
# from repo root
rg -n --hidden -S --iglob '!*node_modules/*' \
  -e 'BEGIN (OPENSSH|PGP|.* PRIVATE KEY)' \
  -e '(password|passwd)\s*=' \
  -e '(token|secret|apikey|api_key)\s*=' \
  -e 'github_pat_[0-9a-zA-Z_]+' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e '\bBearer\s+[A-Za-z0-9\-_\.]+' \
  -e '/home/[a-z][^/]+' \
  -e '\bapplepie\b' \
  -e '\btim@kicker\.dev\b' \
  .
```

### 4.2 Full secret scanners
- **gitleaks** (recommended):
  ```bash
  gitleaks detect --no-git --verbose
  # or scan git history too:
  gitleaks detect --verbose
  ```
- **trufflehog**:
  ```bash
  trufflehog filesystem --only-verified .
  # history:
  trufflehog git --only-verified --since-commit HEAD~100 .
  ```

> If you enable CI, add one of these scanners to PR checks.

---

## 5) Scrubbing sensitive data from history

If something leaked and has already been committed, you must **rewrite history** and force‑push:

### 5.1 Remove paths entirely
```bash
pipx install git-filter-repo  # or: pacman -S python-pipx; pipx install git-filter-repo
git filter-repo --path path/to/secret.file --invert-paths
git push --force-with-lease
```

### 5.2 Replace tokens (in all commits)
Create `replacements.txt`:
```
# Lines are:  literal-search==>replacement
github_pat_ABC123==>***REDACTED***
AKIA...==>***REDACTED***
/home/tim==>/home/USER
applepie==>HOSTNAME
```
Run:
```bash
git filter-repo --replace-text replacements.txt
git push --force-with-lease
```

> **Rotate** any exposed keys immediately at their origin (GitHub, cloud providers, etc). History rewriting does **not** invalidate already-compromised credentials.

---

## 6) Protecting your identity & metadata

- **Email:** If you don’t want your real email in commit metadata:
  
  ```bash
  git config --global user.name "Tim"
  git config --global user.email "tim@users.noreply.github.com"
  ```
  (You said your email can be public; adjust as you prefer.)
  
- **Machine name:** Avoid embedding your hostname in configs. Use variables where possible.

- **License & issues:** Don’t paste logs with secrets in GitHub issues. Consider adding an issue template reminding contributors **not to attach logs** containing tokens.

---

## 7) Systemd user units & environment

- Keep **tokens** out of unit files. Use `Environment=` only for non‑secrets, and use `EnvironmentFile=` for secrets stored in a **non‑tracked** file (in `$XDG_CONFIG_HOME/…` that is ignored by Git).
- Example layout:
  ```bash
  ~/.config/systemd/user/myapp.service        # tracked, no secrets
  ~/.config/myapp/secret.env                  # NOT tracked (in .gitignore)
  ```
- Consider `systemctl --user edit <unit>` instead of editing distro files.

---

## 8) File permissions hygiene

- Scripts in `bin/` executable: `chmod 755`.
- Sensitive files (if any local templates): `chmod 600`.
- `~/.ssh` directory should be `700`; private keys `600`; public keys `644`.
- Avoid world-writable directories in your dotfiles. Set a sane umask in your shell (`umask 022`).

---

## 9) Publishing checklist (pre‑push)

1. `rg` scan (section 4.1) → **0 hits** for secrets.
2. Run **gitleaks** or **trufflehog** locally → **no findings**.
3. Check screenshots with `exiftool` for any metadata.
4. Verify `.gitignore` covers secret paths (section 2).
5. Ensure systemd units don’t embed secrets.
6. Confirm scripts do not contain personal paths; use `$HOME`/XDG.
7. Review the diff (`git diff --staged`) one last time.

---

## 10) Reporting a vulnerability

If you discover a security issue in this repository, **please do not** open a public issue. Instead, email:

**tim@kicker.dev**

I will respond as soon as possible and coordinate a fix. Thank you!

---

## 11) Final notes for dotfiles

- Dotfiles are inherently personal—assume an attacker can read them. Do not rely on **security by obscurity**.
- Keep **secrets out**, and keep **backups** of your private material separately (password managers, encrypted vaults).
- Periodically re‑run the scanners and rotate tokens you suspect may have been exposed elsewhere.
