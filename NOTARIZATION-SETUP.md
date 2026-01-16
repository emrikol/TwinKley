# TwinKley Notarization Setup - Detailed Instructions

## Part 1: Create App-Specific Password

### Step 1: Open Apple ID Settings
1. Open your web browser
2. Go to: https://appleid.apple.com
3. Click "Sign In" (top right)
4. Enter your Apple ID email and password
5. Complete two-factor authentication if prompted

### Step 2: Navigate to App-Specific Passwords
1. Once logged in, you'll see your account page
2. Look for the "Sign-In and Security" section
3. Click on "App-Specific Passwords" (or it might say "Generate Password")
4. You may need to enter your password again

### Step 3: Generate the Password
1. Click the "+" button (or "Generate an app-specific password")
2. When prompted for a name, type: **TwinKley Notarization**
3. Click "Create"
4. Apple will show you a password that looks like: **xxxx-xxxx-xxxx-xxxx**
5. **IMPORTANT**: Copy this password immediately! You can't see it again.
   - Select the password and press Cmd+C to copy
   - Or write it down temporarily

### Step 4: Store in Keychain (DO THIS NEXT)
Once you have the password copied, come back to Terminal and run this command:

```bash
xcrun notarytool store-credentials "TwinKley-Notary" \
  --apple-id "YOUR_APPLE_ID@example.com" \
  --team-id "3T9RX85H44" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

**Replace:**
- `YOUR_APPLE_ID@example.com` - Your actual Apple ID email
- `xxxx-xxxx-xxxx-xxxx` - The password you just copied

**Example:**
If your Apple ID is johndoe@gmail.com and password is abcd-efgh-ijkl-mnop:
```bash
xcrun notarytool store-credentials "TwinKley-Notary" \
  --apple-id "johndoe@gmail.com" \
  --team-id "3T9RX85H44" \
  --password "abcd-efgh-ijkl-mnop"
```

### Step 5: Verify It Worked
The command will prompt you to confirm. Type "y" and press Enter.

You should see:
```
Credentials validated.
Credentials saved to Keychain.
```

---

## What Happens Next?

Once credentials are stored, I'll help you:
1. Create a ZIP archive of the app
2. Submit it to Apple for notarization
3. Wait for Apple's approval (~5-10 minutes)
4. "Staple" the notarization ticket to the app
5. App is ready for distribution!

---

## Need Help?

If you get stuck:
- Make sure you're using the correct Apple ID (the one with the developer account)
- The password must be a new app-specific password (not your regular password)
- Copy/paste carefully - the password has dashes in specific places

Ready? Let me know when you've completed the `xcrun notarytool store-credentials` command!
