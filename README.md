# Swift Devcontainer

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aoyn1xw/swift-devcontainer?quickstart=1)
[![Docker Pulls](https://img.shields.io/docker/pulls/ayon1xw/swift-devcontainer?logo=docker&logoColor=white&color=2496ED)](https://hub.docker.com/r/ayon1xw/swift-devcontainer)

Build and sign iOS apps on Linux — no Mac, no Xcode.

![Demo of the Swift devcontainer](demo.gif)

---

## What's Included

| Tool | Purpose |
|------|---------|
| Swift 6.3.3 | Compile Swift packages and iOS-targeted apps |
| xtool | Cross-compile Swift for iOS on Linux |
| zsign | Sign IPAs without Xcode |
| Theos installer | iOS tweak and app development; installed on demand during onboarding |
| fetch-xcode | Download Xcode.xip from Apple CDN (via xcodereleases.com) |

---

## Getting Started

**Codespaces** — click the button above. First build takes ~10-15 min, cached after that.

**VS Code** — clone the repo, open it, run `Dev Containers: Reopen in Container`.

**Docker Compose** — runs code-server on port `8080`. Set your password first:

```bash
cp .env.example .env   # edit CODE_SERVER_PASSWORD
docker compose up -d
```

Port `2222` is mapped to the container's SSH port `22` for Cursor Remote-SSH. Compose starts SSH only after a valid password is supplied.

> **Security requirement:** `CODE_SERVER_PASSWORD` must be set in `.env` (or as an environment variable) before starting. It must be at least 8 characters and must not be a known default. The container fails closed instead of starting code-server with a placeholder password.

Verify everything works:
```sh
swift --version && xtool --help && zsign -h && ls $THEOS
```

### First-time onboarding

On first interactive shell or attach, an interactive guide walks you through setup step by step (passwords → Swift check → optional Theos/Xcode/SDK setup → next commands). Non-interactive hooks print instructions rather than blocking automation. The core onboarding marker is written only after a valid password and core tools are available.

```sh
onboard              # run the full walkthrough
onboard --status     # see what's configured
onboard --reset      # start over
configure-passwords --interactive   # change passwords later
```

You'll need an Apple Developer account and an **Xcode.xip** before the xtool step. Use the built-in downloader:

```sh
fetch-xcode              # download latest stable Xcode.xip
fetch-xcode --list       # see available versions
fetch-xcode --version 16.3  # specific version
```

See the [xtool Linux install guide](https://xtool.sh/documentation/xtooldocs/installation-linux) for more details.

**Passwords:** set a strong `CODE_SERVER_PASSWORD` in `.env` (Docker Compose) or your shell before opening the dev container. Onboarding rejects known defaults and optionally lets you set an SSH password. Password configuration is stored with restrictive file permissions.

Set `SKIP_ONBOARDING=1` to disable auto-start.

---

## Use in Your Own Repo

Copy `.devcontainer/` into any repo and open a Codespace — your project builds with the same toolchain.

---

## Limitations

- No Xcode, no Simulator, no SwiftUI previews

---

## Troubleshooting

**Blank screen behind dev tunnels** — configure code-server with your proxy domain:

```bash
docker compose exec swift-dev bash -c 'configure-passwords --interactive'
# Configure proxy-domain through your code-server configuration mechanism,
# preserving the existing password and never using a known default.
docker compose restart
```

If issues persist, use VS Code's built-in tunnel instead of forwarding port `8080`.

---

## License

Config files only. See upstream licenses: [Swift](https://github.com/swiftlang/swift) · [xtool](https://github.com/xtool-org/xtool) · [zsign](https://github.com/zhlynn/zsign) · [Theos](https://github.com/theos/theos)

Questions? Open an issue or hit me on Discord at `ayon1xw`.
