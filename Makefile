# Makefile for a simple Qt6 application

# Set default goal so `make` (no args) builds `all`
.DEFAULT_GOAL := all

COMPILER = g++
# Use pkg-config to get the necessary compiler flags for Qt6
# This adds include paths, etc.
QT_CFLAGS = $(shell pkg-config --cflags Qt6Widgets)
# Add -fPIC so object files are position-independent and avoid copy-relocation linker errors
CFLAGS = -Wall -Wextra -std=c++17 -g -fPIC $(QT_CFLAGS)

# Use pkg-config to get the necessary linker flags for Qt6
# This adds library paths and links the required libraries (-lQt6Widgets, etc.)
QT_LDFLAGS = $(shell pkg-config --libs Qt6Widgets)
LDFLAGS = -pie $(QT_LDFLAGS)

SRCDIR = gui
SOURCES = $(wildcard $(SRCDIR)/*.cpp)
BUILD_DIR = build
# Let's give the app a more descriptive name
EXECUTABLE = firefox-profile-chooser

NAME = $(EXECUTABLE)
OBJECTS = $(patsubst $(SRCDIR)/%.cpp,$(BUILD_DIR)/%.o,$(SOURCES))
TARGET = $(BUILD_DIR)/$(EXECUTABLE)

# ---- Cross-build switches ---------------------------------------------------
# Set WINDOWS=1 or MACOS=1 to attempt cross-building for those platforms.
WINDOWS ?= 0
MACOS   ?= 0

ifeq ($(WINDOWS),1)
MXE_CC := $(shell command -v x86_64-w64-mingw32.static-g++ 2>/dev/null || true)
ifeq ($(MXE_CC),)
$(error MXE toolchain not found. Run 'make check-windows-deps' for instructions.)
endif
COMPILER := $(MXE_CC)
# Try to query the cross pkg-config if available
QT_CFLAGS := $(shell command -v x86_64-w64-mingw32.static-pkg-config >/dev/null 2>&1 && x86_64-w64-mingw32.static-pkg-config --cflags Qt6Widgets || echo)
QT_LDFLAGS := $(shell command -v x86_64-w64-mingw32.static-pkg-config >/dev/null 2>&1 && x86_64-w64-mingw32.static-pkg-config --libs Qt6Widgets || echo)
CFLAGS := -Wall -Wextra -std=c++17 -g -fPIC $(QT_CFLAGS)
LDFLAGS := -static $(QT_LDFLAGS)
endif

ifeq ($(MACOS),1)
# For macOS cross builds we expect OSXCROSS to be set to the osxcross root.
ifndef OSXCROSS
$(error OSXCROSS environment variable not set. Run 'make check-macos-deps' for instructions.)
endif
# osxcross provides 'o64-clang' and related tools under target/bin
COMPILER := $(OSXCROSS)/target/bin/o64-clang
# Cross-building Qt apps for macOS is non-trivial. Leave Qt flags empty and require the user to provide suitable Qt for macOS or build on macOS.
QT_CFLAGS :=
QT_LDFLAGS :=
CFLAGS := -Wall -Wextra -std=c++17 -g -fPIC $(QT_CFLAGS)
LDFLAGS := $(QT_LDFLAGS)
endif
# -----------------------------------------------------------------------------

all: $(TARGET)

$(TARGET): $(OBJECTS) | $(BUILD_DIR)
	@echo "Linking..."
	$(COMPILER) $(OBJECTS) -o $@ $(LDFLAGS)
	@echo "Build complete: $(TARGET)"

$(BUILD_DIR)/%.o: $(SRCDIR)/%.cpp | $(BUILD_DIR)
	@echo "Compiling $<..."
	$(COMPILER) $(CFLAGS) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# The install target now uses the new executable name
install-desktop: $(TARGET)
	@echo "Installing .desktop file and setting as default handler..."
	mkdir -p $(HOME)/.local/share/applications
	printf "[Desktop Entry]\nName=Firefox Profile Chooser\nExec=$(CURDIR)/$(TARGET) %%U\nType=Application\nTerminal=false\nMimeType=x-scheme-handler/http;x-scheme-handler/https;\n" > $(HOME)/.local/share/applications/$(NAME).desktop
	xdg-settings set default-url-scheme-handler http $(NAME).desktop || true
	xdg-settings set default-url-scheme-handler https $(NAME).desktop || true
	@echo "Installation complete."

# ---- Dependency checks and helper targets ----------------------------------
.PHONY: check-deps check-linux-deps check-windows-deps check-macos-deps build-windows build-macos native-macos native-windows check-native-macos-deps check-native-windows-deps

check-deps: check-linux-deps check-windows-deps check-macos-deps

check-linux-deps:
	@echo "Checking Linux Qt6 (Qt6Widgets) dependency..."
	@if pkg-config --exists Qt6Widgets 2>/dev/null; then \
		echo "Qt6Widgets found via pkg-config."; \
	else \
		echo "Qt6Widgets not found. Please install Qt6 development packages for your distro:"; \
		echo "  Debian/Ubuntu: sudo apt install qt6-base-dev qt6-tools-dev-tools pkg-config"; \
		echo "  Arch (pacman): sudo pacman -S qt6-base pkg-config"; \
		echo "  Fedora (dnf): sudo dnf install qt6-qtbase-devel qt6-qttools-devel pkgconf-pkg-config"; \
		echo "  openSUSE (zypper): sudo zypper install libqt6-qtbase-devel pkg-config"; \
		echo "After installing, rerun 'make'."; \
	fi

check-windows-deps:
	@echo "Checking MXE (Windows cross) toolchain..."
	@if command -v x86_64-w64-mingw32.static-g++ >/dev/null 2>&1; then \
		echo "Found MXE/MinGW-w64 cross compiler."; \
	else \
		echo "MXE cross compiler not found. To cross-build for Windows on Linux, consider MXE:"; \
		echo "  1) Install system prerequisites (Debian/Ubuntu example):"; \
		echo "     sudo apt update && sudo apt install build-essential git python3 gcc g++ make ccache"; \
		echo "  2) Clone MXE and build Qt (may take long):"; \
		echo "     git clone https://github.com/mxe/mxe.git /opt/mxe"; \
		echo "     cd /opt/mxe && make gcc qtbase qtchooser -j\$$(nproc)"; \
		echo "  3) Add MXE compilers to PATH, e.g. export PATH=/opt/mxe/usr/bin:\$$PATH"; \
		echo "When MXE is installed, run: make WINDOWS=1"; \
	fi

check-macos-deps:
	@echo "Checking osxcross (macOS cross) toolchain..."
	@if [ -n "${OSXCROSS}" ] && [ -x "${OSXCROSS}/target/bin/o64-clang" ]; then \
		echo "Found osxcross at $${OSXCROSS}."; \
	else \
		echo "osxcross not found or OSXCROSS env var not set."; \
		echo "To cross-build for macOS you can use osxcross (requires Xcode SDK):"; \
		echo "  1) On a mac, download Xcode (or Xcode command line tools) and extract the SDK as a tarball."; \
		echo "  2) On Linux, follow https://github.com/tpoechtrager/osxcross to build osxcross and place the Xcode SDK into osxcross/tarballs."; \
		echo "  3) Set OSXCROSS=/path/to/osxcross and export it in your shell, then run: make MACOS=1"; \
	fi

# Native build helpers for users building on their own machines (macOS / Windows)
check-native-macos-deps:
	@echo "Checking native macOS Qt6 (Qt6Widgets)..."
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "Not running on macOS. Run this target on a Mac."; exit 1; \
	fi
	@if pkg-config --exists Qt6Widgets 2>/dev/null; then \
		echo "Qt6Widgets found via pkg-config."; \
	else \
		if command -v brew >/dev/null 2>&1 && brew --prefix qt@6 >/dev/null 2>&1; then \
			echo "Qt6 (Homebrew) detected. You may need to export PKG_CONFIG_PATH before building:"; \
			echo "  export PKG_CONFIG_PATH=$$(brew --prefix qt@6)/lib/pkgconfig"; \
		else \
			echo "Qt6 not found. Install via Homebrew:"; \
			echo "  brew install qt@6 pkg-config"; \
		fi; \
		exit 1; \
	fi

native-macos: check-native-macos-deps
	@echo "Building natively on macOS..."
	@PKG_CONFIG_PATH=$$(brew --prefix qt@6 2>/dev/null || echo "")/lib/pkgconfig $(MAKE) all

check-native-windows-deps:
	@echo "Checking native Windows Qt6 (MSYS2/MinGW64 or Visual Studio)..."
	@if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Widgets 2>/dev/null; then \
		echo "Qt6Widgets available via pkg-config (MSYS2/MinGW)."; \
	else \
		echo "Qt6 not found via pkg-config. On MSYS2 (recommended) run:"; \
		echo "  pacman -S mingw-w64-x86_64-qt6 mingw-w64-x86_64-toolchain pkg-config"; \
		echo "Then open the mingw64 shell and run: make"; \
		echo "Alternatively, use the Qt Online Installer + Visual Studio and build from Qt Creator or set up MSVC toolchain manually."; \
		exit 1; \
	fi

native-windows: check-native-windows-deps
	@echo "Building natively on Windows (MSYS2/mingw64 recommended)..."
	@$(MAKE) all
# -----------------------------------------------------------------------------

clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete."

.PHONY: all clean install-desktop
