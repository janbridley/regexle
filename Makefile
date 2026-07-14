# HexGrid — CLI-driven build / test / run workflow.
#
#   make build   compile the iOS app (xcodebuild, no simulator needed)
#   make test    run the geometry unit tests (swift test)
#   make run     launch the grid in a native macOS window (swift run HexGridMac)
#   make bench   benchmark generation + matching for n=2…8 (release build)
#   make clean   remove build artifacts
#
# The app and the tests share one portable geometry core (Sources/HexGridCore),
# so the math that renders in the app is exactly what the tests assert.

PROJECT  := HexGrid.xcodeproj
TARGET   := HexGrid
CONFIG   := Debug
# Build against the iphoneos SDK with no -destination. This compiles + links
# the app without device/simulator discovery, sidestepping the out-of-date
# CoreSimulator runtime on this machine. Use `-target` (not `-scheme`) so the
# presence of Package.swift can't resolve to the package's scheme instead.
SDK      := iphoneos

.DEFAULT_GOAL := help

.PHONY: help build test run bench clean

help: ## Show available targets
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the iOS app (iphoneos SDK, no device/simulator needed)
	@ret=0; xcodebuild \
		-project $(PROJECT) \
		-target $(TARGET) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		CODE_SIGNING_ALLOWED=NO \
		build || ret=$$?; \
	echo "----"; echo "xcodebuild exit code: $$ret"; exit $$ret

test: ## Run unit tests on the geometry core
	swift test

run: ## Launch the grid in a native, resizable macOS window
	swift run HexGridMac

bench: ## Benchmark generation + matching for n=2–8 (prints charts + CSV)
	swift run -c release bench

clean: ## Remove build artifacts
	xcodebuild -project $(PROJECT) clean || true
	swift package clean || true
	rm -rf out .build
