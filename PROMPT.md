Build me a small macOS menu bar app called **NoSleep**. I'm the only person who will ever use it. It should not be distributed, sandboxed or submitted to the App Store.

## What it does
- It's a menu bar item only, sitting next to the clock. No Dock icon, no main window (`LSUIElement = YES`).
- **Left-click** toggles No Sleep Mode on or off.
  - **On:** the Mac and the display both stay awake indefinitely, with no dimming, no display sleep and no system idle sleep, until I click again. Use an IOKit power assertion (`IOPMAssertionCreateWithName` with `kIOPMAssertionTypePreventUserIdleDisplaySleep`, which also prevents system idle sleep). Release the assertion when it's turned off and when the app quits.
  - **Off:** normal macOS sleep behaviour.
- **Right-click** opens a small menu with:
  - A status line ("No Sleep: On" / "No Sleep: Off"), disabled and for info only
  - Quit NoSleep (releases the assertion first)
- **Icon:** SF Symbols coffee cup, rendered as a template image so it adapts to light and dark menu bars.
  - Off: `cup.and.saucer`
  - On: `cup.and.saucer.fill`
  - Add a tooltip showing the current state.

## Startup behaviour
- The app launches automatically when I log in to my Mac.
- It **always starts in the Off state**. It does not remember the previous state. One click is needed to enable it.
- Register it as a login item using `SMAppService.mainApp.register()`. If that fails for an ad-hoc-signed app, fall back to a LaunchAgent plist in `~/Library/LaunchAgents`. Do this automatically on first run, with no prompt.

## Hard constraints
- No accounts, sign-in, network access, analytics, update checks or settings window. Fully offline.
- No admin or sudo rights, and no `pmset` changes. It only uses power assertions, so quitting the app always restores normal behaviour.
- Minimal, dependency-free code: Swift + AppKit (`NSStatusItem`). No third-party packages.

## My environment
- macOS 26.6, Apple Silicon (arm64)
- Only **Xcode Command Line Tools** are installed (Swift 6.1). Full Xcode is not, so don't rely on `xcodebuild` or an `.xcodeproj`.

## How to build it
1. Use a Swift Package (or plain `swiftc`) in this folder.
2. Write a `build.sh` that:
   - compiles a release build
   - assembles `NoSleep.app` (`Contents/MacOS`, `Contents/Info.plist` with `LSUIElement`, bundle ID `com.mitch.nosleep`, minimum macOS 13)
   - ad-hoc code signs it (`codesign --force --deep --sign -`)
   - copies it to `/Applications/NoSleep.app`, replacing any old copy and quitting a running instance first
   - launches it
3. Run the build yourself and confirm it works:
   - The icon appears in the menu bar.
   - After a click, `pmset -g assertions` shows the NoSleep assertion.
   - After a second click, the assertion is gone.
   - Right-click → Quit removes the icon and the assertion.
   - The login item is registered (check System Settings → General → Login Items, or `sfltool dumpbtm`).
4. Add a short README with how to rebuild, and how to uninstall (remove the login item and delete the app).
