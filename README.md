# Gutenkern

A local kerning pair generator for type designers. It runs entirely on your computer and does not need an internet connection.

Builds are **unsigned**. macOS Gatekeeper and Windows SmartScreen (or another antivirus) will often warn that the publisher is unknown. That is expected for a free open-source app without a paid certificate. Gutenkern is not malware; follow the steps below to install it anyway.

**Requirements:** macOS 13 or later, or 64-bit Windows 10/11.

Download the latest files from [Releases](https://github.com/Archibaldero/Gutenkern/releases/latest).

## Install on macOS

1. Download `Gutenkern-macOS.zip` from the latest release and unzip it.
2. Drag `Gutenkern.app` into **Applications**.
3. Open it with a Control-click (or right-click) on the app → **Open** → **Open**. A normal double-click is often blocked the first time.

If macOS still refuses to open it:

1. Open **System Settings → Privacy & Security**.
2. Scroll to the message that Gutenkern was blocked.
3. Click **Open Anyway**, then confirm **Open**.

If the Mac says the app is **damaged** and cannot be opened (this happens with some unsigned downloads), remove the quarantine flag in Terminal, then try **Open** again:

```sh
xattr -cr /Applications/Gutenkern.app
```

Intel Macs can run the Apple Silicon build through Rosetta.

## Install on Windows

Use the installer unless you want a portable copy.

### Installer

1. Download `Gutenkern-Setup.exe` from the latest release and run it.
2. If **Windows protected your PC** appears (SmartScreen): click **More info**, then **Run anyway**.
3. Finish the setup wizard. You can install for your user only; administrator rights are not required.

### Portable

1. Download `Gutenkern.exe` and `l10n.json` into the **same folder**. Without `l10n.json` next to the exe, translations will not load.
2. Double-click `Gutenkern.exe`. If SmartScreen appears, use **More info → Run anyway** as above.

### If Windows or an antivirus still blocks it

- **File is blocked after download:** in File Explorer, right-click the `.exe` → **Properties** → tick **Unblock** → **OK**, then run it again.
- **Microsoft Defender:** open **Windows Security → Virus & threat protection → Protection history**. If Gutenkern was quarantined, restore it and allow it on the device.
- **Other antivirus:** open the quarantine or blocked-files list, restore Gutenkern, and add an exception for `Gutenkern-Setup.exe` or the folder that contains `Gutenkern.exe`.

The app is a self-contained 64-bit Windows build. It will not run on 32-bit Windows or on Windows on ARM without x64 emulation.

## Build from source

**macOS** (Xcode command-line tools):

```sh
scripts/build-macos.sh
```

The app is written to `dist/Gutenkern.app`.

**Windows** cannot be built on a Mac. On Windows with .NET 8, or via the **Windows** GitHub Actions workflow:

```bat
dotnet test windows/Gutenkern.Tests/Gutenkern.Tests.csproj -c Release
dotnet publish windows/Gutenkern/Gutenkern.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -o dist/windows
```

## License

[MIT](LICENSE)
