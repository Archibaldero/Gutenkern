# Gutenkern

A local kerning pair generator for type designers. Available on macOS and Windows.

## Windows

The Windows app is built on GitHub Actions (it cannot be built on a Mac).

1. Open the **Actions** tab, choose the **Windows** workflow, and open the latest green run.
2. Download the **Gutenkern-windows** artifact. It contains `Gutenkern-Setup.exe` (installer) and a portable `Gutenkern.exe` plus `l10n.json`.
3. For a lasting download, push a tag such as `v1.0.0`. That creates a GitHub Release with the same files.

The installer is unsigned, so Windows SmartScreen may warn that the publisher is unknown.
