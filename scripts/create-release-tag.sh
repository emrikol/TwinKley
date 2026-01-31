#!/bin/bash
# Create a release tag with CHANGELOG validation
# Usage: ./scripts/create-release-tag.sh v1.0.0-beta5 "Release message"

set -e

VERSION_TAG="$1"
RELEASE_MESSAGE="$2"

# Validate arguments
if [ -z "$VERSION_TAG" ]; then
	echo "Usage: $0 <version-tag> [release-message]"
	echo ""
	echo "Example: $0 v1.0.0-beta5 \"Release v1.0.0-beta5\""
	exit 1
fi

# Validate version tag format
if [[ ! "$VERSION_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-.*)?$ ]]; then
	echo "❌ ERROR: Invalid version tag format: $VERSION_TAG"
	echo ""
	echo "Expected format: vX.Y.Z or vX.Y.Z-suffix"
	echo "Examples: v1.0.0, v1.0.0-beta1, v1.0.0-rc1"
	exit 1
fi

VERSION="${VERSION_TAG#v}"

echo "🔍 Pre-release checks for $VERSION_TAG..."
echo ""

# Check 1: CHANGELOG.md exists
if [ ! -f CHANGELOG.md ]; then
	echo "❌ ERROR: CHANGELOG.md not found!"
	exit 1
fi

# Check 2: Version exists in CHANGELOG
if ! grep -q "## \[$VERSION\]" CHANGELOG.md; then
	echo "❌ ERROR: Version $VERSION not found in CHANGELOG.md!"
	echo ""
	echo "Add this section to CHANGELOG.md:"
	echo ""
	echo "  ## [$VERSION] - $(date +%Y-%m-%d)"
	echo "  "
	echo "  ### Added"
	echo "  - New features"
	echo "  "
	echo "  ### Changed"
	echo "  - Changes to existing functionality"
	echo "  "
	echo "  ### Fixed"
	echo "  - Bug fixes"
	echo ""
	exit 1
fi

echo "✅ CHANGELOG.md has entry for $VERSION"

# Check 3: CHANGELOG has real date (not TBD)
if grep "## \[$VERSION\] - TBD" CHANGELOG.md > /dev/null; then
	echo "❌ ERROR: CHANGELOG has 'TBD' date for $VERSION"
	echo ""
	echo "Update to: ## [$VERSION] - $(date +%Y-%m-%d)"
	exit 1
fi

echo "✅ CHANGELOG.md has proper date"

# Check 4: CHANGELOG is committed
if git diff --name-only | grep -q "CHANGELOG.md"; then
	echo "❌ ERROR: CHANGELOG.md has uncommitted changes!"
	echo ""
	echo "Please commit CHANGELOG.md before creating the tag."
	exit 1
fi

if git diff --cached --name-only | grep -q "CHANGELOG.md"; then
	echo "❌ ERROR: CHANGELOG.md has staged but uncommitted changes!"
	echo ""
	echo "Please commit CHANGELOG.md before creating the tag."
	exit 1
fi

echo "✅ CHANGELOG.md is committed"

# Check 5: Working directory is clean (warning only, not blocking)
if [ -n "$(git status --porcelain)" ]; then
	echo "⚠️  WARNING: Working directory has uncommitted/untracked files:"
	echo ""
	git status --short
	echo ""
	echo "   Continuing anyway (warnings don't block releases)..."
	echo ""
fi

# Check 6: Version in Settings.swift matches tag
SETTINGS_VERSION=$(grep 'static let version = "' Packages/TwinKleyCore/Sources/TwinKleyCore/Settings.swift | sed 's/.*"\(.*\)".*/\1/')
if [ "$SETTINGS_VERSION" != "$VERSION" ]; then
	echo "❌ ERROR: Version mismatch!"
	echo ""
	echo "  Settings.swift: $SETTINGS_VERSION"
	echo "  Tag:            $VERSION"
	echo ""
	echo "Please update Settings.swift to match the tag version."
	exit 1
fi

echo "✅ Settings.swift version matches tag"

# All checks passed - create the tag
echo ""
echo "📦 Creating tag $VERSION_TAG..."

if [ -z "$RELEASE_MESSAGE" ]; then
	# Interactive tag message
	git tag -a "$VERSION_TAG"
else
	# Use provided message
	git tag -a "$VERSION_TAG" -m "$RELEASE_MESSAGE"
fi

echo ""
echo "✅ Tag created successfully!"
echo ""
echo "Next steps:"
echo "  1. Review the tag: git show $VERSION_TAG"
echo "  2. Push the tag: git push origin $VERSION_TAG"
echo "  3. Watch GitHub Actions: https://github.com/emrikol/TwinKley/actions"
