# set default goal so `make` (no args) builds `all`
.DEFAULT_GOAL := all

COMPILER=g++
CFLAGS=-Wall -Wextra -Werror -std=c++11 -g
LDFLAGS= -lfltk
SRCDIR=gui
SOURCES=$(wildcard $(SRCDIR)/*.cpp)
BUILD_DIR=build
EXECUTABLE=app

NAME=$(EXECUTABLE)
OBJECTS=$(patsubst $(SRCDIR)/%.cpp,$(BUILD_DIR)/%.o,$(SOURCES))
TARGET=$(BUILD_DIR)/$(EXECUTABLE)

all: $(TARGET)

$(TARGET): $(OBJECTS) | $(BUILD_DIR)
	$(COMPILER) $(OBJECTS) -o $@ $(LDFLAGS)

$(BUILD_DIR)/%.o: $(SRCDIR)/%.cpp | $(BUILD_DIR)
	$(COMPILER) $(CFLAGS) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

install-desktop: $(TARGET)
	mkdir -p $(HOME)/.local/share/applications
	printf "[Desktop Entry]\nName=$(NAME)\nExec=$(CURDIR)/$(TARGET) %%U\nType=Application\nTerminal=false\nMimeType=x-scheme-handler/http;x-scheme-handler/https;\n" > $(HOME)/.local/share/applications/$(NAME).desktop
	xdg-settings set default-url-scheme-handler http $(NAME).desktop || true
	xdg-settings set default-url-scheme-handler https $(NAME).desktop || true

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean install-desktop