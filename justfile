# Tasks for the Daily ZGT monorepo. Run `just` to list them.

default:
    @just --list

# Write TeclaTokens.swift from packages/design-tokens/tecla.json
tokens:
    python3 packages/design-tokens/generate-tecla-tokens

# Fail when TeclaTokens.swift does not match tecla.json
tokens-check:
    python3 packages/design-tokens/generate-tecla-tokens --check

# Generate the Xcode project from apps/macos/project.yml
mac-generate:
    cd apps/macos && xcodegen generate

# Build the macOS app (Debug)
mac-build: mac-generate
    cd apps/macos && xcodebuild -project DailyZGT.xcodeproj -scheme DailyZGT -destination 'platform=macOS' -derivedDataPath build build

# Run the macOS tests
mac-test: mac-generate
    cd apps/macos && xcodebuild -project DailyZGT.xcodeproj -scheme DailyZGT -destination 'platform=macOS' -derivedDataPath build test

# Build the Release app and copy it to /Applications
mac-install:
    ./apps/macos/scripts/install.sh

# Install the website dependencies
web-install:
    cd apps/website && pnpm install

# Start the website dev server
web-dev:
    cd apps/website && pnpm dev

# Build the website
web-build:
    cd apps/website && pnpm build

# Build the Windows app with warnings as errors
win-build:
    dotnet build apps/windows/DailyZGT.slnx

# Run the Windows tests, except the end-to-end UI tests
win-test:
    dotnet test apps/windows/DailyZGT.slnx --filter "Category!=UI"

# Build, then drive the real app through UI Automation (takes the mouse and keyboard while it runs)
win-e2e: win-build
    dotnet test apps/windows/tests/DailyZGT.UiTests --no-build

# Build, test and check the tokens; run before every Windows commit
win-check: tokens-check win-build win-test

# Start the Windows app in debug with the panel open
win-run *args:
    dotnet run --project apps/windows/src/DailyZGT -- --show-panel {{args}}
