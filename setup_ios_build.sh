#!/bin/bash

echo "🍎 Setting up iOS build environment..."

# Navigate to iOS directory
cd ios

# Install bundler if not present
if ! command -v bundle &> /dev/null; then
    echo "📦 Installing bundler..."
    gem install bundler
fi

# Install gems from Gemfile
echo "📦 Installing Ruby gems..."
bundle install

# Clean previous CocoaPods installation
echo "🧹 Cleaning previous CocoaPods installation..."
rm -rf Pods
rm -f Podfile.lock
rm -rf ~/Library/Caches/CocoaPods

# Update CocoaPods repo
echo "🔄 Updating CocoaPods repository..."
bundle exec pod repo update

# Install pods
echo "📱 Installing iOS pods..."
bundle exec pod install

echo "✅ iOS build environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Run 'flutter clean'"
echo "2. Run 'flutter pub get'"
echo "3. Try 'flutter build ios --no-codesign'"
