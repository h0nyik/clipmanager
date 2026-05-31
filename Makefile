.PHONY: build build-debug app dmg clean run lint

# Build universal release binary (arm64 + x86_64)
build:
	swift build -c release --arch arm64 --arch x86_64

# Debug build for development
build-debug:
	swift build -c debug

# Assemble .app bundle (universal release)
app: build
	bash Scripts/build-app.sh release universal

# Build .app and package as DMG
dmg: app
	bash Scripts/create-dmg.sh

# Clean build artifacts
clean:
	rm -rf .build build

# Run in debug mode (no .app bundle — for development only)
run:
	swift run --arch arm64

# SwiftLint (install with: brew install swiftlint)
lint:
	swiftlint --strict
