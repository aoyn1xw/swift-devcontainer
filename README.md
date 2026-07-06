# Swift Devcontainer

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aoyn1xw/swift-devcontainer?quickstart=1)
[![Docker Pulls](https://img.shields.io/docker/pulls/ayon1xw/swift-devcontainer?logo=docker&logoColor=white&color=2496ED)](https://hub.docker.com/r/ayon1xw/swift-devcontainer)

Build and sign iOS apps on Linux — no Mac, no Xcode.

![Demo of the Swift devcontainer](demo.gif)

---

## What's Included

| Tool | Purpose |
|------|---------|
| Swift 6.3.2 | Compile Swift packages and iOS-targeted apps |
| xtool | Cross-compile Swift for iOS on Linux |
| zsign | Sign IPAs without Xcode |
| Theos | iOS tweak and app development |

---

## Getting Started

**Codespaces** — click the button above. First build takes ~10-15 min, cached after that.

**VS Code** — clone the repo, open it, run `Dev Containers: Reopen in Container`.

**Docker Compose** — runs code-server on port `8080`. Set your password first:

```bash
cp .env.example .env   # edit CODE_SERVER_PASSWORD
docker compose up -d
```

Port `2222` is also mapped for SSH access (used by Cursor Remote-SSH). Both ports are included in `docker-compose.yml` by default.

> **Note:** `CODE_SERVER_PASSWORD` must be set in `.env` (or as an environment variable) before starting. Startup will fail clearly if it is not set — the image no longer ships with a default `changeme` password baked in.

Verify everything works:
```sh
swift --version && xtool --help && zsign -h && ls $THEOS
```

### First-time onboarding

On first launch, an interactive guide walks you through setup step by step (passwords → Swift check → `xtool setup` → next commands). It starts automatically when you open a terminal or attach to the dev container.

```sh
onboard              # run the full walkthrough
onboard --status     # see what's configured
onboard --reset      # start over
configure-passwords --interactive   # change passwords later
```

You'll need an Apple Developer account and a downloaded **Xcode.xip** before the xtool step. See the [xtool Linux install guide](https://xtool.sh/documentation/xtooldocs/installation-linux).

**Passwords:** set `CODE_SERVER_PASSWORD` in `.env` (Docker Compose) or your shell before opening the dev container. Onboarding also prompts you to replace the default `changeme` password and optionally set an SSH password.

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
docker compose exec swift-dev bash -c "mkdir -p /home/vscode/.config/code-server && cat > /home/vscode/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8080
auth: password
password: changeme
cert: false
proxy-domain: your-tunnel-domain.devtunnels.ms
EOF"
docker compose restart
```

If issues persist, use VS Code's built-in tunnel instead of forwarding port `8080`.

---

## License

Config files only. See upstream licenses: [Swift](https://github.com/swiftlang/swift) · [xtool](https://github.com/xtool-org/xtool) · [zsign](https://github.com/zhlynn/zsign) · [Theos](https://github.com/theos/theos)

Questions? Open an issue or hit me on Discord at `ayon1xw`.
