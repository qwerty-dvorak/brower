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

clean:
	@echo "Cleaning build files..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete."

.PHONY: all clean install-desktop
