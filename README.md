# Swift Devcontainer (xtool + zsign)

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

This environment is **not** suitable for:

- Xcode usage
- iOS Simulator or device debugging
- SwiftUI previews
- App Store or TestFlight submission

---

## What's Included

| Tool | Version | Purpose |
|------|---------|---------|
| **Swift** | latest (via swiftly) | Build Swift packages and apps |
| **xtool** | v1.16.1 | Cross-compile Swift for iOS on Linux |
| **zsign** | v0.7 | Code-sign IPAs without Xcode |

All tools are compiled **during the image build**, so they're ready the moment your Codespace starts.

---

## Quick Start

Click the button above, or:

1. Go to the repo on GitHub
2. Click **Code → Codespaces → Create codespace on main**
3. Wait ~5-10 min for the first build (cached after that)
4. Verify:
   ```sh
   swift --version
   xtool --help
   zsign -h
   ```

### Use This Template on Your Own Repo

You can copy this dev container config into any repo:

1. Copy the `.devcontainer/` folder into your project
2. Push to GitHub
3. Open a Codespace — your project will build with the same iOS toolchain

Or fork this repo and customize it.

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
  Dockerfile          # Builds Swift + xtool + zsign from source
README.md
```

---

## Rebuilding the Container

Changes to `Dockerfile` or `devcontainer.json` require a rebuild:

- **Codespaces:** Delete the codespace and create a new one (or use Full Rebuild)
- **VS Code:** Run **Dev Containers: Rebuild Container**

---

## Notes

- All binaries are installed to `/usr/local/bin`
- Tool versions are pinned to avoid upstream breakage
- Build failures cause the Docker image build to fail immediately
- This is not a full Mac replacement — it's an alternative using free and open source tools
- If you want to push apps to TestFlight/App Store you still need a Mac for final submission
- There is no Simulator — this is a Linux environment, not macOS

## Related Resources

- [theos](https://github.com/theos) - iOS toolchain for building tweaks and jailbreak apps

## License

This repo contains only configuration files. Licensing for included tools:

- [xtool](https://github.com/xtool-org/xtool)
- [zsign](https://github.com/zhlynn/zsign)