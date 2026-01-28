#!/bin/bash
# Install all git hooks for TwinKley development
#
# This script copies hooks from hooks/ to .git/hooks/ and makes them executable

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/hooks"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "📦 Installing git hooks..."
echo ""

if [ ! -d "$GIT_HOOKS_DIR" ]; then
	echo "❌ ERROR: .git/hooks directory not found"
	echo "Are you in a git repository?"
	exit 1
fi

INSTALLED=0

for hook in "$HOOKS_DIR"/*; do
	if [ -f "$hook" ]; then
		HOOK_NAME=$(basename "$hook")

		# Skip non-hook files
		if [[ "$HOOK_NAME" == "README.md" ]] || [[ "$HOOK_NAME" == "*.sample" ]]; then
			continue
		fi

		echo "Installing $HOOK_NAME..."
		cp "$hook" "$GIT_HOOKS_DIR/$HOOK_NAME"
		chmod +x "$GIT_HOOKS_DIR/$HOOK_NAME"
		INSTALLED=$((INSTALLED + 1))
	fi
done

echo ""
echo "✅ Installed $INSTALLED git hook(s)"
echo ""
echo "Hooks installed:"
echo "  • pre-commit: Prevents committing local-only files (NOTES.md, etc.)"
echo "  • pre-push: Validates CHANGELOG.md when pushing version tags"
echo ""
echo "These hooks will run automatically with git commands."
