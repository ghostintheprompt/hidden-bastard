#!/bin/bash
# Launch Hidden Bastard for testing

echo "🚀 Building Hidden Bastard..."
xcodebuild -project HiddenBastard.xcodeproj -scheme HiddenBastard -configuration Debug build 2>&1 | grep -E "(BUILD|error:)" | tail -3

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "🎯 Launching Hidden Bastard..."
    open ~/Library/Developer/Xcode/DerivedData/HiddenBastard-*/Build/Products/Debug/HiddenBastard.app
else
    echo "❌ Build failed!"
    exit 1
fi
