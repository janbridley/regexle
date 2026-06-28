# HexGrid — CLI-driven build / test / visualize workflow.
#
#   make build   compile the iOS app (xcodebuild, no simulator needed)
#   make test    run the geometry unit tests (swift test)
#   make vis     render the grid to a PNG and open it (swift run vis)
#   make clean   remove build artifacts
#
# All three tools share one portable geometry core (Sources/HexGridCore),
# so the math that renders in the app is exactly what the tests assert and
# what `vis` draws.

PROJECT  := HexGrid.xcodeproj
TARGET   := HexGrid
CONFIG   := Debug
# Build against the iphoneos SDK with no -destination. This compiles + links
# the app without device/simulator discovery, sidestepping the out-of-date
# CoreSimulator runtime on this machine. Use `-target` (not `-scheme`) so the
# presence of Package.swift can't resolve to the package's scheme instead.
SDK      := iphoneos

VIS_N    ?= 4
VIS_SIZE ?= 800
VIS_OUT  ?= out/grid.png

.DEFAULT_GOAL := help

.PHONY: help build test vis run clean

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

vis: ## Render the grid to a PNG and open it
	@mkdir -p $(dir $(VIS_OUT))
	swift run vis -- --n $(VIS_N) --size $(VIS_SIZE) --out $(VIS_OUT)
	@open $(VIS_OUT)

run: ## Launch the grid in a native, resizable macOS window
	swift run HexGridMac

clean: ## Remove build artifacts
	xcodebuild -project $(PROJECT) clean || true
	swift package clean || true
	rm -rf out .build
