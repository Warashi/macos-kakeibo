SCHEME=Kakeibo
PROJECT=Kakeibo.xcodeproj
DERIVED_DATA=build/DerivedData
APP_NAME=$(SCHEME).app
INSTALL_PATH=/Applications

.PHONY: generate build release run lint lint-swiftlint lint-swiftformat format test clean install

generate:
	mint run xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		build

release: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		build

run: build
	open $(DERIVED_DATA)/Build/Products/Debug/$(SCHEME).app

lint: lint-swiftlint lint-swiftformat

lint-swiftlint:
	mint run swiftlint lint

lint-swiftformat:
	mint run swiftformat --lint .

format:
	mint run swiftlint lint --autocorrect
	mint run swiftformat .

test: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		-enableCodeCoverage YES \
		CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf $(DERIVED_DATA)
	rm -rf $(PROJECT)

install: release
	@echo "Installing $(APP_NAME) to $(INSTALL_PATH)..."
	@if [ -d "$(INSTALL_PATH)/$(APP_NAME)" ]; then \
		echo "Removing existing $(APP_NAME) from $(INSTALL_PATH)..."; \
		rm -rf "$(INSTALL_PATH)/$(APP_NAME)"; \
	fi
	cp -R "$(DERIVED_DATA)/Build/Products/Release/$(APP_NAME)" "$(INSTALL_PATH)/"
	@echo "Installation complete: $(INSTALL_PATH)/$(APP_NAME)"
