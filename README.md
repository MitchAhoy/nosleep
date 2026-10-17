# NoSleep

A tiny menu bar app that keeps the Mac and its display awake.

- **Left-click** the coffee cup to toggle No Sleep Mode (filled cup = on).
- **Right-click** (or Control-click) for the status line and **Quit NoSleep**.
- It always starts **Off**. It starts at login.
- It only uses an IOKit power assertion (`PreventUserIdleDisplaySleep`), so turning it off or quitting always brings back normal sleep. No `pmset` changes, no sudo, no network.

Check it's working: `pmset -g assertions | grep NoSleep`

## Install on a new Mac

Requires the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/MitchAhoy/nosleep.git
cd nosleep
./build.sh
```

## Rebuild

```sh
./build.sh
```

This compiles a release build with `swiftc` (Command Line Tools only). It then assembles and ad-hoc signs `build/NoSleep.app`, quits any running copy, installs it to `/Applications/NoSleep.app` and launches it.

On first launch the app registers itself as a login item with `SMAppService`. If that fails, it writes `~/Library/LaunchAgents/com.mitch.nosleep.plist` instead.

> `build.sh` works around a Command Line Tools bug, where a stale `module.modulemap` in `usr/include/swift` breaks every `import`. It hides that file from the compiler with a VFS overlay. To fix it permanently, run `sudo rm /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap`, or reinstall the Command Line Tools.

## Uninstall

1. Right-click the cup and choose **Quit NoSleep**.
2. Remove the login item: **System Settings → General → Login Items & Extensions**, select NoSleep and click **–**. Also remove the fallback LaunchAgent if it exists:
   ```sh
   rm -f ~/Library/LaunchAgents/com.mitch.nosleep.plist
   ```
3. Delete the app:
   ```sh
   rm -rf /Applications/NoSleep.app
   ```
4. Optional: to clear the background-item record as well, run `sfltool resetbtm`. Note that this resets **all** login items, and macOS will ask again for the others.
