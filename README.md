<p align="center">
  <img src="assets/banner.svg" alt="MacCaffeine — keep your Mac awake" width="100%">
</p>

<p align="center">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%2013%2B-1b1207?style=flat-square&logo=apple">
  <img alt="language" src="https://img.shields.io/badge/Swift-6-ff9f43?style=flat-square&logo=swift&logoColor=white">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-e9b878?style=flat-square">
</p>

A tiny menu-bar app that keeps your Mac awake. One click. Filled cup = awake. ☕

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/rgoomar/maccaffeine/main/install.sh | bash
```

This downloads the latest release into `/Applications` and starts it.

You can also download `MacCaffeine.zip` from [Releases](https://github.com/rgoomar/maccaffeine/releases). The app is not notarized, so macOS blocks the first launch of a browser download. To allow it, go to **System Settings → Privacy & Security** and click **Open Anyway**.

## Use

Click the cup in the menu bar:

- **Keep awake**: stay awake until you turn it off.
- **Awake for 30 minutes / 1 / 2 / 5 hours**: stay awake, then turn off automatically.
- **Open at Login**: start MacCaffeine when you log in.

The menu shows the current state, the end time of a timer, or why it stopped.

## How it works

MacCaffeine holds the same power assertions as `caffeinate -dims`:

- No admin password and no changes to system settings.
- macOS releases the assertions when the app quits or crashes, so your Mac cannot get stuck awake.
- It turns off by itself when the battery is below 20% (on battery power) or when the Mac is critically hot.

> [!NOTE]
> With the lid closed, macOS stays awake only on the power adapter with an external display connected. On battery, closing the lid puts the Mac to sleep.

## Build from source

Requires the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh
open MacCaffeine.app
```

## Release

Push a tag. GitHub Actions builds a universal (Apple silicon + Intel) app and attaches `MacCaffeine.zip` to the release.

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## Credits

MacCaffeine started as a fork of [CaffeineOSS](https://github.com/Kuberwastaken/caffeineOSS) by Kuber Mehta. It now uses a different approach (no admin rights, no `pmset`), so it is a separate project.

## License

MIT. See [LICENSE](LICENSE).
