SCHEME=Kakeibo
PROJECT=Kakeibo.xcodeproj
DERIVED_DATA=build/DerivedData

.PHONY: generate build run lint format test clean

generate:
	xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		build

run: build
	open $(DERIVED_DATA)/Build/Products/Debug/$(SCHEME).app

lint:
	swiftlint lint
	swiftformat --lint .

format:
	swiftlint lint --autocorrect
	swiftformat .

test: generate
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination 'platform=macOS,arch=arm64' \
		-derivedDataPath $(DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO test

clean:
	rm -rf $(DERIVED_DATA)
	rm -rf $(PROJECT)
