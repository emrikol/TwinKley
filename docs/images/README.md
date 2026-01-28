# Screenshots Needed for Release

This directory will contain screenshots for the README.

## Required Screenshots

### 1. preferences-screenshot.png
**What to capture:**
- Launch TwinKley.app
- Open Preferences (menu bar icon → Preferences)
- Take a screenshot showing:
  - Menu bar icon visible in top-right
  - Preferences window with all tabs visible
  - Clean, professional appearance

**Recommended size:** At least 1200px wide for clarity

**How to capture:**
```bash
# Launch the app
open ~/Applications/TwinKley.app

# Open Preferences window
# Click menu bar icon → Preferences

# Take screenshot (⌘+Shift+4, then Space to capture window)
# Save to: docs/images/preferences-screenshot.png
```

### 2. sync-demo.gif (Optional but Recommended)
**What to capture:**
- Record a short video showing:
  1. Brightness keys being pressed (or Control Center slider being adjusted)
  2. Display brightness changing
  3. Keyboard backlight syncing to match

**Recommended tool:** [Kap](https://getkap.co/) or QuickTime + GIF converter

**Duration:** 5-10 seconds

**How to create:**
```bash
# Install Kap (if not already installed)
brew install --cask kap

# Record the demo
# 1. Open Kap
# 2. Select screen area (show keyboard and brightness controls)
# 3. Press Record
# 4. Adjust brightness using keys or Control Center
# 5. Stop recording
# 6. Export as GIF
# 7. Save to: docs/images/sync-demo.gif
```

## After Creating Screenshots

Update the main README.md to reference the actual screenshot files instead of placeholders.

## Tips for Good Screenshots

1. **Clean desktop:** Hide unnecessary windows and icons
2. **Good lighting:** Ensure keyboard backlight is visible
3. **High resolution:** Use Retina display capture
4. **Readable text:** All UI elements should be clearly legible
5. **No sensitive data:** Remove any personal information from view
