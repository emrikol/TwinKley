# Git Hooks for TwinKley

This directory contains git hooks that enforce project conventions and prevent common mistakes.

## Available Hooks

### pre-commit
Prevents accidentally committing local-only files:
- `NOTES.md` - Technical research notes
- `NEXT-STEPS-RELEASE.md` - Release planning notes
- Other files in `.gitignore`

### pre-push
Validates CHANGELOG.md when pushing version tags:
- Ensures version exists in CHANGELOG.md
- Checks for proper date (not TBD)
- Validates format: `## [X.Y.Z] - YYYY-MM-DD`

## Installation

**Option 1: Install all hooks at once** (recommended)
```bash
./scripts/install-hooks.sh
```

**Option 2: Install individually**
```bash
cp hooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
cp hooks/pre-push .git/hooks/pre-push && chmod +x .git/hooks/pre-push
```

## How Git Hooks Work

**Committed in repo** (synced via git):
- `hooks/pre-commit` - The hook script
- `hooks/pre-push` - The hook script

**Local to each developer** (NOT committed):
- `.git/hooks/pre-commit` - Active hook (copied from hooks/)
- `.git/hooks/pre-push` - Active hook (copied from hooks/)

**Why this separation?**
- Git doesn't sync `.git/hooks/` by design (security)
- We store hooks in `hooks/` and provide install scripts
- Each developer must install hooks locally

## Bypassing Hooks (Use Sparingly!)

```bash
# Skip pre-commit hook
git commit --no-verify

# Skip pre-push hook
git push --no-verify
```

⚠️ **Warning:** Only bypass hooks if you know what you're doing!

## Testing Hooks

Test the pre-push hook without actually pushing:

```bash
# Create a test tag
git tag v9.9.9-test

# Try to push it (hook will validate CHANGELOG)
git push origin v9.9.9-test

# Clean up test tag
git tag -d v9.9.9-test
```
