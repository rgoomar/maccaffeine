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
brew install --cask rgoomar/tap/maccaffeine
```

Or download `MacCaffeine.zip` from [Releases](https://github.com/rgoomar/maccaffeine/releases), unzip it, and move `MacCaffeine.app` to `/Applications`. The app is signed and notarized by Apple.

## Use

Click the cup in the menu bar:

- **Keep awake**: stay awake until you turn it off.
- **Awake for 30 minutes / 1 / 2 / 5 hours**: stay awake, then turn off automatically.
- **Open at Login**: start MacCaffeine when you log in.
- **About MacCaffeine**: show the version and a link to this repository.

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

Local builds are ad-hoc signed. The app runs in the App Sandbox with the hardened runtime, as the Mac App Store requires.

## Release

Push a tag:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

GitHub Actions then:

1. Builds a universal (Apple silicon + Intel) app and signs it with the Developer ID certificate.
2. Notarizes and staples it.
3. Attaches `MacCaffeine.zip` to the GitHub release.
4. Updates the cask in [rgoomar/homebrew-tap](https://github.com/rgoomar/homebrew-tap).

Repository secrets:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12_BASE64` | Developer ID Application certificate and private key (`.p12`), base64 |
| `DEVELOPER_ID_P12_PASSWORD` | Password of the `.p12` |
| `NOTARY_KEY_P8_BASE64` | App Store Connect API key (`.p8`), base64 |
| `NOTARY_KEY_ID` | Key ID of the API key |
| `NOTARY_ISSUER_ID` | Issuer ID of the API key |
| `TAP_DEPLOY_KEY` | SSH private key with write access to `rgoomar/homebrew-tap` |

## Credits

MacCaffeine started as a fork of [CaffeineOSS](https://github.com/Kuberwastaken/caffeineOSS) by Kuber Mehta. It now uses a different approach (no admin rights, no `pmset`), so it is a separate project.

## License

MIT. See [LICENSE](LICENSE).
