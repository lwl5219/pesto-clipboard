.PHONY: build build-debug test clean install dmg bump-version locales-export locales-import locales-status

PROJECT_NAME = PestoClipboard
APP_NAME = Pesto Clipboard
PROJECT_DIR = PestoClipboard
BUILD_DIR = build
VERSION ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "dev")
DMG_NAME = PestoClipboard-$(VERSION).dmg
XCODE_DEVELOPER_DIR := $(shell if [ -d /Applications/Xcode.app/Contents/Developer ]; then printf '%s' /Applications/Xcode.app/Contents/Developer; fi)
XCODEBUILD = $(if $(XCODE_DEVELOPER_DIR),DEVELOPER_DIR=$(XCODE_DEVELOPER_DIR) )xcodebuild

build:
	$(XCODEBUILD) -project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build

build-debug:
	$(XCODEBUILD) -project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build

test:
	$(XCODEBUILD) test \
		-project $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj \
		-scheme $(PROJECT_NAME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR)

install: build
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" /Applications/

dmg: build
	@echo "Creating DMG: $(DMG_NAME)"
	@rm -rf dmg-contents $(DMG_NAME)
	@mkdir -p dmg-contents
	@cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME).app" dmg-contents/
	@if command -v create-dmg &> /dev/null; then \
		create-dmg \
			--volname "Pesto Clipboard" \
			--window-pos 200 120 \
			--window-size 600 400 \
			--icon-size 100 \
			--icon "$(APP_NAME).app" 150 185 \
			--hide-extension "$(APP_NAME).app" \
			--app-drop-link 450 185 \
			"$(DMG_NAME)" \
			dmg-contents/ || true; \
	else \
		hdiutil create -volname "Pesto Clipboard" -srcfolder dmg-contents -ov -format UDZO "$(DMG_NAME)"; \
	fi
	@rm -rf dmg-contents
	@echo "Created: $(DMG_NAME)"
	@shasum -a 256 "$(DMG_NAME)"

clean:
	rm -rf $(BUILD_DIR) dmg-contents *.dmg

# Bump version: make bump-version V=0.0.4
bump-version:
ifndef V
	$(error V is required. Usage: make bump-version V=0.0.4)
endif
	@sed -i '' 's/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = $(V);/g' $(PROJECT_DIR)/$(PROJECT_NAME).xcodeproj/project.pbxproj
	@echo "Version bumped to $(V)"
	@echo ""
	@echo "Next steps:"
	@echo "  git add -A && git commit -m 'Bump version to $(V)'"
	@echo "  git tag v$(V) && git push origin main --tags"

# Localization management
locales-export:
	@./scripts/xcstrings.py export

locales-import:
	@./scripts/xcstrings.py import

locales-status:
	@./scripts/xcstrings.py status
