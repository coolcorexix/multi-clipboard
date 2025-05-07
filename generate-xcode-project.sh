#!/bin/bash

# Generate Xcode project
swift package generate-xcodeproj

# Build the project
xcodebuild \
    -scheme MultiClipboard \
    -configuration Release \
    -derivedDataPath build \
    -sdk macosx \
    -destination 'platform=macOS,arch=x86_64' \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Automatic" \
    MACOSX_DEPLOYMENT_TARGET="13.0" \
    PRODUCT_BUNDLE_IDENTIFIER="com.multiclipboard.app" \
    PRODUCT_NAME="MultiClipboard" \
    MARKETING_VERSION="1.0.0" \
    CURRENT_PROJECT_VERSION="1" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--deep"

# The app will be in build/Build/Products/Release/MultiClipboard.app ``