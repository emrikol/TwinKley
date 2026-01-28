# TODO

## UX Improvements

### Auto-Update Loading Indicator
When user clicks "Check for Updates...", show an immediate loading dialog:
- Display: "Checking for updates..." with spinner
- Prevents 10-second dead time where nothing appears to happen
- Sparkle provides delegate methods for this:
  - `updater:didFindValidUpdate:` - update found
  - `updaterDidNotFindUpdate:` - no update
  - `updater:didAbortWithError:` - error
- Implementation: Add SPUStandardUpdaterControllerDelegate to show progress

**Priority:** Medium (UX polish)
**Effort:** Small (~30 mins)

