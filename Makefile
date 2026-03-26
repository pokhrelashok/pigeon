# Makefile for pigeon
# Highly-automated build and install script

PROJECT    = pigeon.xcodeproj
SCHEME     = pigeon
CONFIGURATION = Release
DERIVED_DATA  = build_output
INSTALL_DIR   = /Applications
PRODUCT_NAME  = Pigeon
APP_NAME   = $(PRODUCT_NAME).app
DMG_NAME   = $(PRODUCT_NAME).dmg
BUILD_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)

# Common xcodebuild flags
# CODE_SIGN_IDENTITY="" / CODE_SIGNING_REQUIRED=NO / CODE_SIGNING_ALLOWED=NO
# allow CI runners without a Mac Development certificate to build successfully.
XCODEBUILD_FLAGS = \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-configuration $(CONFIGURATION) \
	-derivedDataPath $(DERIVED_DATA) \
	-skipPackagePluginValidation \
	-skipMacroValidation \
	ARCHS="arm64" \
	ONLY_ACTIVE_ARCH=NO \
	CODE_SIGN_IDENTITY="-" \
	CODE_SIGNING_REQUIRED=YES \
	CODE_SIGNING_ALLOWED=YES

.PHONY: all build install clean help dmg release

all: build install

help:
	@echo "Usage:"
	@echo "  make dmg      - Build and create DMG"
	@echo "  make release  - Tag and push a new release"
	@echo "  make clean    - Remove build artifacts"

build:
	@echo "Building $(SCHEME)..."
	xcodebuild $(XCODEBUILD_FLAGS) build
	@if [ -d "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/pigeon.app" ]; then \
		mv "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/pigeon.app" "$(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/$(APP_NAME)"; \
	fi

install: build
	@echo "Installing to $(INSTALL_DIR)..."
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME)" ]; then \
		echo "Removing old version..."; \
		rm -rf "$(INSTALL_DIR)/$(APP_NAME)"; \
	fi
	cp -R "$(BUILD_PATH)" "$(INSTALL_DIR)/"
	@echo "Installed successfully! You can find $(PRODUCT_NAME) in your Applications folder."

dmg: build
	@echo "Creating DMG..."
	mkdir -p $(DERIVED_DATA)/dmg
	ditto "$(BUILD_PATH)" $(DERIVED_DATA)/dmg/$(APP_NAME)
	ln -s /Applications $(DERIVED_DATA)/dmg/Applications
	hdiutil create -volname $(PRODUCT_NAME) -srcfolder $(DERIVED_DATA)/dmg -ov -format UDZO $(DMG_NAME)
	rm -rf $(DERIVED_DATA)/dmg

release:
	./release.sh

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(DERIVED_DATA)
	rm -f build_error.log build_result.log
