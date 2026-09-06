# Sharing configuration safely

[Back to the overview](../README.md)

Share the configuration bundle, not a copy of your entire home directory.
Application data belongs outside this repository: browser and messaging
profiles, calendar tokens, KWallet, Anki collections and API keys, clipboard
history, quick notes, vaults and machine backups.

## Review files and history

```bash
git status --short
git diff --stat
git diff --cached --stat
git ls-files

# With Gitleaks installed, scan local files and all reachable Git history.
gitleaks dir . --redact
gitleaks git . --log-opts="--all" --redact
```

A secret scanner does not prove that a repository contains no personal data.
Also review home-directory paths, email addresses, monitor serials, SSIDs,
private hostnames, project names and screenshots. Reports themselves can contain
sensitive matches; keep them outside the repository and use redaction.

`.gitignore` excludes local images in `assets/`, common credential files,
databases, logs and backups. Ignore rules do not remove files already tracked
by Git and do not clean old commits. Public account handles in repository URLs
or application IDs, and upstream author names in license notices, are expected.

## Git identity

Git records author and committer names and email addresses in every commit.
Check the identity that this repository will use before committing:

```bash
git var GIT_AUTHOR_IDENT
git var GIT_COMMITTER_IDENT
git config --show-origin --get user.email
```

If you want to keep your personal or work address private, copy your GitHub
noreply address from **GitHub → Settings → Emails**, then set `user.email` for
this repository with `git config --local`. Use your public handle for
`user.name` if you prefer that attribution. Changing these settings affects
future commits only.

## Existing public history

Deleting a value from today's files does not remove it from old revisions.
Changing repository visibility also cannot retract existing clones or forks.
If a credential was exposed, rotate it. If history needs cleaning, plan it as a
separate operation: it changes commit IDs and affects other clones. Review the
[GitHub guide to removing sensitive data](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)
before rewriting or force-pushing shared history.

## Visuals and support requests

Screenshots can expose notifications, calendar events, media history, clipboard
contents, browser tabs, Wi-Fi names and account avatars. Use sample content when
creating public previews. Review logs for the same information before attaching
them to issues.

Keep the root [LICENSE](../LICENSE), [NOTICE](../NOTICE),
[third-party notices](../THIRD_PARTY.md), bundled upstream licenses and source
archives with any redistributed configuration bundle.
