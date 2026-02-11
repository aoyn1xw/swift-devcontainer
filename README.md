# Swift Devcontainer (xtool + zsign)

This repository provides a **GitHub Codespaces / Dev Container** setup that installs and builds the following tools **at container image build time**:

- **Swift** (installed via `swiftly`)
- **xtool** (built from source)
- **zsign** (built from source with all required dependencies)

When the Codespace starts, all tools are already installed and available on `PATH`.

---

## Purpose

This setup is intended for:

- Building and testing Swift-based open-source tools
- Working with `xtool` and `zsign` on Linux
- Having a fully reproducible development environment
- Avoiding local system setup and dependency issues

All heavy work happens **once during the image build**, not every time the Codespace starts.

---

## Repository Structure

```
.devcontainer/
  devcontainer.json
  Dockerfile
  install-tools.sh
README.md
```

### File Overview

* **Dockerfile**
  Installs system dependencies and runs the build script during image creation.

* **install-tools.sh**
  Clones, builds, and installs Swift, xtool, and zsign.

* **devcontainer.json**
  Configures the dev container and build context for Codespaces and VS Code.

---

## Usage

### GitHub Codespaces (Recommended)

1. Open the repository on GitHub
2. Click **Code → Codespaces → Create codespace**
3. Wait for the container image to build (first run only)

Verify installation:

```sh
which swift
which xtool
which zsign

swift --version
xtool --help
zsign -h
```

---

### Local Dev Container (VS Code)

**Requirements**

* Docker
* Visual Studio Code
* Dev Containers extension

**Steps**

1. Open the repository in VS Code
2. Run **Dev Containers: Reopen in Container**
3. Wait for the container image to build

---

## Rebuilding the Container

Any changes to the following files require a rebuild:

* `Dockerfile`
* `install-tools.sh`
* `devcontainer.json`

To rebuild:

* Run **Codespaces: Rebuild Container**
* Or **Dev Containers: Rebuild Container** in VS Code

Changes will not apply without rebuilding.

---

## Notes

* All binaries are installed to `/usr/local/bin`
* `/usr/local/bin` is included in `PATH`
* Tool versions are pinned to avoid unexpected upstream breakage
* Build failures cause the Docker image build to fail immediately
* Tis is not made for a full mac replacment but rather a alternative with free and open source tools if you wanna push apps to testflight/Appstore you still need a mac
* There will never be a Simulator as this is still a linux env and not a mac 
---

## License

This repository contains only configuration files.

Licensing for included tools is defined in their upstream repositories:

* xtool: [https://github.com/xtool-org/xtool](https://github.com/xtool-org/xtool)
* zsign: [https://github.com/zhlynn/zsign](https://github.com/zhlynn/zsign)
