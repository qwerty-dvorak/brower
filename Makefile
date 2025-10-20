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

# first try the cross-pkg-config
QT_CFLAGS := $(shell x86_64-w64-mingw32.static-pkg-config --cflags Qt6Widgets 2>/dev/null || echo)
QT_LDFLAGS := $(shell x86_64-w64-mingw32.static-pkg-config --libs  Qt6Widgets 2>/dev/null || echo)

# if that failed, pull headers and libs straight out of MXE/usr
ifeq ($(strip $(QT_CFLAGS)),)
    MXE_PREFIX := $(shell dirname $(dir $(MXE_CC)))
    MXE_TRIPLET := $(patsubst %-g++,%,$(notdir $(MXE_CC)))
    QT_CFLAGS := \
      -I$(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/include \
      -I$(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/include/QtWidgets \
      -I$(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/include/QtGui \
      -I$(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/include/QtCore
endif
ifeq ($(strip $(QT_LDFLAGS)),)
    MXE_PREFIX := $(shell dirname $(dir $(MXE_CC)))
    MXE_TRIPLET := $(patsubst %-g++,%,$(notdir $(MXE_CC)))
    QT_LDFLAGS := \
      -L$(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/lib \
      -lQt6Widgets -lQt6Gui -lQt6Core \
      -lz -lpng -lharfbuzz -lfreetype -lbz2 -lbrotlidec -lbrotlicommon \
      -lpcre2-16 -lzstd \
      -lopengl32 -lgdi32 -luser32 -lshell32 -luuid -lole32 -limm32 -lwinmm \
      -ldwmapi -luxtheme -lversion -lshlwapi -ldxgi -ld3d11 -ld3d12 \
      -ldwrite -lws2_32 -lauthz -luserenv -lnetapi32 -lntdll -lsynchronization
    # Add Qt platform plugin and its dependencies
    QT_LDFLAGS += \
      $(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/plugins/platforms/libqwindows.a \
      -lQt6OpenGL -loleaut32 -lsetupapi -lwinspool -lwtsapi32 -lshcore -lcomdlg32 -ld3d9 \
      -lmpr -lruntimeobject -ldxguid -lglib-2.0 -lintl -liconv -latomic -ld2d1 \
      $(MXE_PREFIX)/$(MXE_TRIPLET)/qt6/plugins/styles/libqmodernwindowsstyle.a
endif

CFLAGS   := -Wall -Wextra -std=c++17 -Os -fPIC -DNDEBUG -D_WIN32 -DWIN32 -D_WINDOWS $(QT_CFLAGS)
LDFLAGS  := -static -static-libgcc -static-libstdc++ -s -Wl,--gc-sections $(QT_LDFLAGS) -lQt6EntryPoint
EXECUTABLE := firefox-profile-chooser.exe
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
CFLAGS := -Wall -Wextra -std=c++17 -g -fPIC -D__APPLE__ -D__MACH__ $(QT_CFLAGS)
LDFLAGS := $(QT_LDFLAGS)
EXECUTABLE := firefox-profile-chooser.app
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

# Windows installation target
install-windows: $(TARGET)
	@echo "Installing Firefox Profile Chooser on Windows..."
	@INSTALL_DIR="$(CURDIR)/$(BUILD_DIR)"; \
	INSTALL_DIR_WIN=$$(echo $$INSTALL_DIR | sed 's|/|\\|g'); \
	EXE_PATH="$$INSTALL_DIR_WIN\\$(EXECUTABLE)"; \
	echo "Windows Registry Editor Version 5.00" > install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\Classes\\FirefoxProfileChooser]" >> install-handler.reg; \
	echo "@=\"URL:Firefox Profile Chooser Protocol\"" >> install-handler.reg; \
	echo "\"URL Protocol\"=\"\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\Classes\\FirefoxProfileChooser\\DefaultIcon]" >> install-handler.reg; \
	echo "@=\"$$EXE_PATH,0\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\Classes\\FirefoxProfileChooser\\shell\\open\\command]" >> install-handler.reg; \
	echo "@=\"\\\"$$EXE_PATH\\\" \\\"%1\\\"\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\RegisteredApplications]" >> install-handler.reg; \
	echo "\"FirefoxProfileChooser\"=\"Software\\\\FirefoxProfileChooser\\\\Capabilities\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\FirefoxProfileChooser\\Capabilities]" >> install-handler.reg; \
	echo "\"ApplicationName\"=\"Firefox Profile Chooser\"" >> install-handler.reg; \
	echo "\"ApplicationDescription\"=\"Choose Firefox profile for links\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "[HKEY_CURRENT_USER\\Software\\FirefoxProfileChooser\\Capabilities\\URLAssociations]" >> install-handler.reg; \
	echo "\"http\"=\"FirefoxProfileChooser\"" >> install-handler.reg; \
	echo "\"https\"=\"FirefoxProfileChooser\"" >> install-handler.reg; \
	echo "" >> install-handler.reg; \
	echo "Registry file created: install-handler.reg"; \
	echo "Applying registry changes..."; \
	regedit.exe //S install-handler.reg 2>/dev/null || reg import install-handler.reg; \
	echo "Registry updated successfully."; \
	echo ""; \
	echo "Creating PowerShell script to set as default browser..."; \
	echo '$$appName = "FirefoxProfileChooser"' > set-default.ps1; \
	echo '$$protocols = @("http", "https")' >> set-default.ps1; \
	echo 'Add-Type -AssemblyName System.Runtime.WindowsRuntime' >> set-default.ps1; \
	echo '$$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $$_.Name -eq "AsTask" -and $$_.GetParameters().Count -eq 1 -and $$_.GetParameters()[0].ParameterType.Name -eq "IAsyncOperation``1" })[0]' >> set-default.ps1; \
	echo 'Function Await($$WinRtTask) {' >> set-default.ps1; \
	echo '    $$asTask = $$asTaskGeneric.MakeGenericMethod($$WinRtTask.GetType().GenericTypeArguments)' >> set-default.ps1; \
	echo '    $$netTask = $$asTask.Invoke($$null, @($$WinRtTask))' >> set-default.ps1; \
	echo '    $$netTask.Wait(-1) | Out-Null' >> set-default.ps1; \
	echo '}' >> set-default.ps1; \
	echo 'foreach ($$protocol in $$protocols) {' >> set-default.ps1; \
	echo '    try {' >> set-default.ps1; \
	echo '        [Windows.System.Launcher, Windows.System, ContentType = WindowsRuntime] | Out-Null' >> set-default.ps1; \
	echo '        $$uri = New-Object System.Uri "$$protocol`://test.com"' >> set-default.ps1; \
	echo '        $$operation = [Windows.System.Launcher]::LaunchUriAsync($$uri)' >> set-default.ps1; \
	echo '        Await $$operation' >> set-default.ps1; \
	echo '        Write-Host "Set $$protocol protocol handler"' >> set-default.ps1; \
	echo '    } catch {' >> set-default.ps1; \
	echo '        Write-Host "Could not set $$protocol programmatically: $$_"' >> set-default.ps1; \
	echo '    }' >> set-default.ps1; \
	echo '}' >> set-default.ps1; \
	echo 'Write-Host ""' >> set-default.ps1; \
	echo 'Write-Host "Firefox Profile Chooser registered. To set as default:"' >> set-default.ps1; \
	echo 'Write-Host "1. Open Settings > Apps > Default apps"' >> set-default.ps1; \
	echo 'Write-Host "2. Search for \"Firefox Profile Chooser\""' >> set-default.ps1; \
	echo 'Write-Host "3. Click it and set as default for HTTP and HTTPS"' >> set-default.ps1; \
	echo 'Write-Host ""' >> set-default.ps1; \
	echo 'Write-Host "Or run: start ms-settings:defaultapps"' >> set-default.ps1; \
	echo "PowerShell script created: set-default.ps1"; \
	echo ""; \
	echo "Running PowerShell script to complete setup..."; \
	powershell.exe -ExecutionPolicy Bypass -File set-default.ps1 2>/dev/null || echo "Note: Run set-default.ps1 manually if needed"; \
	echo ""; \
	echo "Installation complete!"; \
	echo "Opening Windows Settings to set as default browser..."; \
	cmd.exe //C start ms-settings:defaultapps 2>/dev/null || echo "Please manually set default browser in Windows Settings"

# macOS installation target
install-macos: $(TARGET)
	@echo "Installing Firefox Profile Chooser on macOS..."
	@APP_NAME="FirefoxProfileChooser"; \
	APP_BUNDLE="$(BUILD_DIR)/$$APP_NAME.app"; \
	CONTENTS_DIR="$$APP_BUNDLE/Contents"; \
	MACOS_DIR="$$CONTENTS_DIR/MacOS"; \
	RESOURCES_DIR="$$CONTENTS_DIR/Resources"; \
	echo "Creating application bundle structure..."; \
	mkdir -p "$$MACOS_DIR"; \
	mkdir -p "$$RESOURCES_DIR"; \
	echo "Copying executable to bundle..."; \
	cp "$(TARGET)" "$$MACOS_DIR/$$APP_NAME"; \
	chmod +x "$$MACOS_DIR/$$APP_NAME"; \
	echo "Creating Info.plist..."; \
	echo '<?xml version="1.0" encoding="UTF-8"?>' > "$$CONTENTS_DIR/Info.plist"; \
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '<plist version="1.0">' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '<dict>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleDevelopmentRegion</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>en</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleExecutable</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo "    <string>$$APP_NAME</string>" >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleIdentifier</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>com.firefoxprofilechooser.app</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleInfoDictionaryVersion</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>6.0</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleName</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>Firefox Profile Chooser</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleDisplayName</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>Firefox Profile Chooser</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundlePackageType</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>APPL</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleShortVersionString</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>1.0</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleVersion</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>1</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>LSMinimumSystemVersion</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <string>10.13</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>NSHighResolutionCapable</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <true/>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <key>CFBundleURLTypes</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    <array>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '        <dict>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <key>CFBundleURLName</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <string>Web URL</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <key>CFBundleURLSchemes</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <array>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '                <string>http</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '                <string>https</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            </array>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <key>CFBundleTypeRole</key>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '            <string>Viewer</string>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '        </dict>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '    </array>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '</dict>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo '</plist>' >> "$$CONTENTS_DIR/Info.plist"; \
	echo "Info.plist created successfully."; \
	echo ""; \
	echo "Installing application bundle to /Applications..."; \
	if [ -d "/Applications/$$APP_NAME.app" ]; then \
		echo "Removing existing application..."; \
		rm -rf "/Applications/$$APP_NAME.app"; \
	fi; \
	cp -R "$$APP_BUNDLE" /Applications/; \
	echo "Application installed to /Applications/$$APP_NAME.app"; \
	echo ""; \
	echo "Registering application with Launch Services..."; \
	/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/$$APP_NAME.app"; \
	echo ""; \
	echo "Creating AppleScript to set as default browser..."; \
	echo 'tell application "System Events"' > set-default-browser.scpt; \
	echo '    tell application process "System Preferences"' >> set-default-browser.scpt; \
	echo '        activate' >> set-default-browser.scpt; \
	echo '    end tell' >> set-default-browser.scpt; \
	echo 'end tell' >> set-default-browser.scpt; \
	echo 'delay 1' >> set-default-browser.scpt; \
	echo 'do shell script "open x-apple.systempreferences:com.apple.preference.general"' >> set-default-browser.scpt; \
	echo "AppleScript created: set-default-browser.scpt"; \
	echo ""; \
	echo "Installation complete!"; \
	echo ""; \
	echo "To set Firefox Profile Chooser as your default browser:"; \
	echo "1. Go to System Settings > Desktop & Dock"; \
	echo "2. Scroll to 'Default web browser'"; \
	echo "3. Select 'Firefox Profile Chooser' from the dropdown"; \
	echo ""; \
	echo "Or run: open x-apple.systempreferences:com.apple.preference.general"; \
	open x-apple.systempreferences:com.apple.preference.general 2>/dev/null || echo ""

# ---- Dependency checks and helper targets ----------------------------------
.PHONY: check-deps check-linux-deps check-windows-deps check-macos-deps build-windows build-macos native-macos native-windows check-native-macos-deps check-native-windows-deps

check-deps: check-linux-deps check-windows-deps check-macos-deps
	ls -la /home/afish/repos/mxe/usr/bin/x86_64-w64-mingw32*g++
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
		echo "     cd /opt/mxe && make MXE_TARGETS='x86_64-w64-mingw32.static' gcc qt6-qtbase -j\$$(nproc)"; \
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
	@PKG_CONFIG_PATH=$$(brew --prefix qt@6 2>/dev/null || echo "")/lib/pkgconfig CFLAGS="$(CFLAGS) -D__APPLE__ -D__MACH__" $(MAKE) all
	@echo ""
	@echo "Build complete. To install and register as default browser, run:"
	@echo "  make install-macos"

check-native-windows-deps:
	@echo "Checking native Windows Qt6..."
	@if [ "$$(uname -s | grep -i 'MINGW\|MSYS\|CYGWIN')" = "" ]; then \
		echo "Not running on Windows/MSYS2. Run this target on Windows."; exit 1; \
	fi
	@if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Widgets 2>/dev/null; then \
		echo "Qt6Widgets available via pkg-config."; \
	else \
		echo "Qt6 not found. Choose one of these installation methods:"; \
		echo ""; \
		echo "Option 1 - MSYS2 (Recommended for Make builds):"; \
		echo "  1. Install MSYS2 from https://www.msys2.org/"; \
		echo "  2. Open MSYS2 MinGW64 shell and run:"; \
		echo "     pacman -S mingw-w64-x86_64-qt6-base mingw-w64-x86_64-toolchain make pkg-config"; \
		echo "  3. Then run: make native-windows"; \
		echo ""; \
		echo "Option 2 - Qt Online Installer + MSVC:"; \
		echo "  1. Download Qt installer from https://www.qt.io/download-qt-installer"; \
		echo "  2. Install Qt 6 with MSVC 2019 64-bit compiler"; \
		echo "  3. Build using Qt Creator or qmake/cmake"; \
		echo ""; \
		echo "Option 3 - vcpkg:"; \
		echo "  1. Install vcpkg from https://github.com/microsoft/vcpkg"; \
		echo "  2. Run: vcpkg install qt6-base:x64-windows"; \
		echo "  3. Set up toolchain integration as per vcpkg docs"; \
		exit 1; \
	fi

native-windows: check-native-windows-deps
	@echo "Building natively on Windows..."
	@$(MAKE) CFLAGS="$(CFLAGS) -D_WIN32 -DWIN32 -D_WINDOWS" EXECUTABLE="firefox-profile-chooser.exe" all
	@echo ""
	@echo "Build complete. To install and register as default browser, run:"
	@echo "  make install-windows"
# -----------------------------------------------------------------------------

clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete."

.PHONY: all clean install-desktop install-windows install-macos
