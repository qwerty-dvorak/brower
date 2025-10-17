# Firefox Profile Chooser

A minimal Qt6-based Firefox profile chooser.

## Building

### Linux (native)
Requirements:
- Qt6 development packages (Qt6Widgets / qt6-base-dev)
- pkg-config
- g++ (C++17)

Build:
```
make
```

If Qt6 is not found, run:
```
make check-linux-deps
```
Follow the printed distro-specific instructions. Example package manager commands:

- Debian / Ubuntu:
  sudo apt update
  sudo apt install build-essential qt6-base-dev qt6-tools-dev-tools pkg-config

- Arch (pacman):
  sudo pacman -Syu
  sudo pacman -S qt6-base pkg-config

- Fedora (dnf):
  sudo dnf install @development-tools
  sudo dnf install qt6-qtbase-devel qt6-qttools-devel pkgconf-pkg-config

- openSUSE (zypper):
  sudo zypper install -t pattern devel_C_C++
  sudo zypper install libqt6-qtbase-devel pkg-config

### macOS (native)
Requirements:
- Homebrew
- qt@6 and pkg-config (or a Qt installer)
- Xcode command line tools (clang)

Install with Homebrew:
```
brew install qt@6 pkg-config
```
If pkg-config cannot find Qt, set:
```
export PKG_CONFIG_PATH="$(brew --prefix qt@6)/lib/pkgconfig"
```
Build natively on a Mac:
```
make native-macos
```

### Windows (native — MSYS2 / mingw64 recommended)
Requirements:
- MSYS2 (mingw64) or Qt + Visual Studio (use Qt Creator for MSVC)
- pkg-config (MSYS2 package)

Using MSYS2/mingw64:
1. Open the MSYS2 mingw64 shell.
2. Install packages:
```
pacman -Syu
pacman -S mingw-w64-x86_64-qt6 mingw-w64-x86_64-toolchain pkg-config
```
3. Build:
```
make native-windows
```

If you prefer MSVC/Qt installer, open the corresponding Qt/Visual Studio environment and build from Qt Creator or set up the MSVC toolchain manually.

### Cross-building for Windows (from Linux) — MXE
MXE provides a MinGW-w64 cross toolchain and optionally Qt builds. Cross-building Qt apps for Windows from Linux typically requires MXE and building Qt within MXE (can be time-consuming).

To check prerequisites:
```
make check-windows-deps
```

Typical MXE quick steps (summary):
1. Install system prerequisites (example for Debian/Ubuntu):
   sudo apt update
   sudo apt install build-essential git python3 automake bison flex libssl-dev \
       libgpg-error-dev liblzma-dev libbz2-dev libexpat1-dev libzstd-dev \
       libxml2-dev

2. Clone MXE and build:
   git clone https://github.com/mxe/mxe.git /opt/mxe
   cd /opt/mxe
   make gcc qtbase -j$(nproc)

3. Add MXE's /opt/mxe/usr/bin to PATH:
   export PATH=/opt/mxe/usr/bin:$PATH

4. Build this project:
   make WINDOWS=1

Note: MXE and cross-Qt builds may require additional MQE packages or adjustments depending on Qt version.

### Cross-building for macOS (from Linux) — osxcross
Cross-compiling macOS apps on Linux requires osxcross and an Xcode SDK tarball (which must be obtained from Apple/Xcode).

To check prerequisites:
```
make check-macos-deps
```

High-level steps:
1. On a mac, obtain Xcode and generate the SDK tarball, or follow osxcross documentation to extract the SDK.
2. On Linux, follow https://github.com/tpoechtrager/osxcross to build osxcross and place the SDK tarball into osxcross/tarballs.
3. Build osxcross, then export:
   export OSXCROSS=/path/to/osxcross
4. Build this project:
   make MACOS=1

Note: Cross-building Qt apps for macOS is advanced — you will likely need macOS Qt binaries or to build Qt for macOS with osxcross.

## Targets
- make               (build for native Linux)
- make clean
- make install-desktop
- make check-deps
- make check-windows-deps
- make check-macos-deps
- make WINDOWS=1      (attempt Windows cross-build if MXE is installed)
- make MACOS=1        (attempt macOS cross-build if osxcross is configured)
- make native-macos   (build on a native macOS machine)
- make native-windows (build in MSYS2/mingw64 on Windows)

## Limitations and notes
- Cross-building GUI apps and bundling Qt is non-trivial. The provided Makefile helpers check for common toolchains and print instructions but cannot magically provision proprietary SDKs (e.g., Xcode) or prebuilt cross-Qt libraries.
- For guaranteed native macOS builds, consider building on a mac or using CI/macOS runners. For Windows, MXE is a common solution on Linux.
- If you need more automated Docker-based cross-builds, consider creating dedicated Dockerfiles that include the full cross toolchain and Qt built for the target platform.

