# Swift Devcontainer (xtool + zsign + Theos)

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aoyn1xw/swift-devcontainer?quickstart=1)

A ready-to-use cloud dev environment for iOS-targeted Swift development without a Mac.
This setup focuses on compiling, packaging, and signing iOS apps using free and open-source tools on Linux.

---

## Intended Use

This environment is designed for:

- Learning Swift and iOS APIs
- Writing and compiling iOS-targeted Swift code
- Building and packaging IPAs on Linux
- Prototyping app logic without macOS
- Tweak development with Theos

This environment is **not** suitable for:

- Xcode usage
- iOS Simulator or device debugging
- SwiftUI previews
- App Store or TestFlight submission

---

## What's Included

| Tool | Version | Purpose |
|------|---------|---------|
| **Swift** | 6.2.3 | Build Swift packages and apps |
| **xtool** | latest | Cross-compile Swift for iOS on Linux |
| **zsign** | latest (built from source) | Code-sign IPAs without Xcode |
| **Theos** | latest | iOS tweak and app development framework |

All tools are installed **during the image build**, so they're ready the moment your Codespace starts.

---

## Quick Start

Click the button above, or:

1. Go to the repo on GitHub
2. Click **Code → Codespaces → Create codespace on main**
3. Wait ~10-15 min for the first build (cached after that)
4. Verify everything installed correctly:

```sh
swift --version
xtool --help
zsign -h
ls $THEOS
```

### Use This Template on Your Own Repo

Copy the `.devcontainer/` folder into any repo, push to GitHub, and open a Codespace — your project will build with the same iOS toolchain. Or just fork this repo and customize it.

---

### Local Dev Container (VS Code)

**Requirements:** Docker, VS Code, Dev Containers extension

1. Clone the repo
2. Open in VS Code
3. Run **Dev Containers: Reopen in Container**

---

## Repository Structure

```
.devcontainer/
  devcontainer.json   # Codespace/dev container config
  Dockerfile          # Builds Swift + xtool + zsign + Theos
README.md
```

---

## Environment Variables

| Variable | Value |
|----------|-------|
| `THEOS` | `/opt/theos` |
| `THEOS_MAKE_PATH` | `/opt/theos/makefiles` |

---

## Rebuilding the Container

Changes to `Dockerfile` or `devcontainer.json` require a rebuild:

- **Codespaces:** Delete the codespace and create a new one, or use **Full Rebuild**
- **VS Code:** Run **Dev Containers: Rebuild Container**

---

## Notes

- All binaries are installed to `/usr/local/bin`
- Swift is installed from the official swift.org tarball for Ubuntu 24.04, pinned to 6.2.3
- xtool is extracted from its AppImage release using `--appimage-extract` (no FUSE required)
- zsign is compiled from source against the system's `libplist`, `libzip`, `libssl`, and `libminizip`
- Theos is cloned to `/opt/theos` with shallow submodules to keep image size down
- This is not a Mac replacement — it's a Linux-native alternative using free and open source tools
- If you want to push to TestFlight or the App Store you still need a Mac for final submission
- There is no Simulator — this is a Linux environment, not macOS

---

## License

This repo contains only configuration files. See the upstream tools for their own licenses:

- [Swift](https://github.com/swiftlang/swift) — Apache 2.0
- [xtool](https://github.com/xtool-org/xtool) - MIT
- [zsign](https://github.com/zhlynn/zsign) — MIT
- [Theos](https://github.com/theos/theos)
