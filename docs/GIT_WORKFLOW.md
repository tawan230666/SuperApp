# Git recovery and publishing — 2026-09-09

- Source workspace: `/Users/tawan/Project/SuperApp` initially had no `.git`. Commands pwd/status/remote/branch/log verified this.
- Existing SSH remote: `git@github.com:tawan230666/SuperApp.git`; main at `acbb719` (Initial Tipkhun Capital app).
- Safe checkout: `/private/tmp/tipkhun-web-20260909`, branch `feature/web-platform`, based on remote main. No force push or history rewrite.
- Source backup before refactor: `/private/tmp/tipkhun-checkpoint-20260909`; temporary backup is not durable cloud storage.
- Existing GitHub source was older: local redesign, paper engine and tests were absent there. Current local files were copied additively into checkout, preserving remote-only original `assets/tipkhun-logo.png` and all remote history.
- Checkpoint `04cc5e3`: `chore: checkpoint latest Tipkhun Capital app`, pushed to feature branch before Web changes.
- `.gitignore` now excludes local environment secrets, signing files, caches, ephemeral/generated directories and personal images. Pattern scan of staged textual content found no supported key/token/private-key patterns. This is not a comprehensive secret audit. The pre-existing tracked image in `images/` was not modified or re-added; ignoring does not erase old history.

## Workspace permission boundary

This session's managed filesystem policy makes `/Users/tawan/Project/SuperApp/.git` read-only. Commits/pushes therefore use the separate checkout; the source directory itself is still not a normal Git checkout. Do not claim plain `git status` works there yet.

After this session, in a normal user terminal with write access, transfer metadata only after verifying source/checkout match and `.git` is absent. For example:

```sh
cd /Users/tawan/Project/SuperApp
# Verify the clone exists and inspect its latest commit first:
git -C /private/tmp/tipkhun-web-20260909 log -3 --oneline
# No source files are overwritten; refuse if any .git already exists:
if [ ! -e .git ]; then
  cp -R /private/tmp/tipkhun-web-20260909/.git .git
fi
git status --short --branch
git remote -v
```

This metadata step has NOT been run by the agent. If `/private/tmp` was cleared, clone GitHub into another directory and compare before reconnecting; never clone over the current app. Final branch is the durable checkpoint. Merge into main after browser review; no production deploy is configured.

## Phase 2 checkout — 2026-09-10

Current safe checkout: `/private/tmp/tipkhun-phase2-checkout`, branch
`feature/platform-architecture`, starting remote head `2fec65f`. The source
workspace still has no .git. Updated source is copied additively into this
checkout for ordinary commits/pushes; remote history and main are preserved.
The implementation checkpoint explicitly records blocked PostgreSQL acceptance.
