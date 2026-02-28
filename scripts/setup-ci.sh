#!/bin/bash
# Freefall CI Setup Script
# Run this once on your Mac to generate GitHub secrets
# Usage: bash scripts/setup-ci.sh

set -e

TEAM_ID="C4A9WBD5PY"
BUNDLE_ID="com.jamie323.freefall"
KEY_ID="QD9VPLLQQ5"
ISSUER_ID="1cc49820-efe5-4991-92ea-2cfff83351f0"
PROFILE_NAME="Freefall AppStore"
P12_PASSWORD="freefall-ci-2026"
KEYCHAIN_PASSWORD="freefall-ci-2026"

echo ""
echo "=================================="
echo " Freefall CI Setup"
echo "=================================="
echo ""

# ── Step 1: Find distribution certificate ──────────────────────────────────
echo "🔍 Looking for Apple Distribution certificate..."

CERT_NAME=$(security find-certificate -a -c "Apple Distribution" -Z login.keychain 2>/dev/null | grep "alis" | grep "$TEAM_ID\|$BUNDLE_ID\|Apple Distribution" | head -1 | sed 's/.*"alis"<blob>="//' | sed 's/"//')

if [ -z "$CERT_NAME" ]; then
  # Try broader search
  CERT_NAME=$(security find-certificate -a -c "Apple Distribution" -Z login.keychain 2>/dev/null | grep "alis" | head -1 | sed 's/.*"alis"<blob>="//' | sed 's/"//')
fi

if [ -z "$CERT_NAME" ]; then
  echo ""
  echo "❌ No Apple Distribution certificate found in your Keychain."
  echo ""
  echo "Fix: Open Xcode → Settings → Accounts → select your Apple ID"
  echo "     Click 'Manage Certificates' → click + → 'Apple Distribution'"
  echo "     Then re-run this script."
  exit 1
fi

echo "✅ Found: $CERT_NAME"

# ── Step 2: Export cert as p12 ─────────────────────────────────────────────
echo ""
echo "📦 Exporting certificate..."
EXPORT_PATH="$TMPDIR/freefall_dist.p12"

security export \
  -k login.keychain \
  -t identities \
  -f pkcs12 \
  -P "$P12_PASSWORD" \
  -o "$EXPORT_PATH" 2>/dev/null

if [ ! -f "$EXPORT_PATH" ]; then
  echo "❌ Export failed. Try running Keychain Access manually."
  exit 1
fi
echo "✅ Certificate exported"

# ── Step 3: Download provisioning profile ─────────────────────────────────
echo ""
echo "📱 Checking for provisioning profile..."

# Look for existing profile
PROFILE_PATH=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | xargs grep -l "$BUNDLE_ID" 2>/dev/null | xargs grep -l "distribution" 2>/dev/null | head -1)

if [ -z "$PROFILE_PATH" ]; then
  PROFILE_PATH=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | xargs grep -l "$BUNDLE_ID" 2>/dev/null | head -1)
fi

if [ -z "$PROFILE_PATH" ]; then
  echo ""
  echo "⚠️  No provisioning profile found for $BUNDLE_ID"
  echo ""
  echo "You need to create one first:"
  echo "  1. Go to: https://developer.apple.com/account/resources/profiles/list"
  echo "  2. Click + → App Store → select '$BUNDLE_ID' → Distribution cert → name it '$PROFILE_NAME'"
  echo "  3. Download it → open it (double-click installs it)"
  echo "  4. Re-run this script"
  echo ""
  echo "Alternatively: Open Xcode → open Freefall project → Signing & Capabilities"
  echo "  → uncheck 'Automatically manage signing'"
  echo "  → re-check it → Xcode will create the profile automatically"
  echo ""
  read -p "Press Enter after you've installed the profile, or Ctrl+C to exit..."
  
  PROFILE_PATH=$(find ~/Library/MobileDevice/Provisioning\ Profiles -name "*.mobileprovision" 2>/dev/null | xargs grep -l "$BUNDLE_ID" 2>/dev/null | head -1)
  
  if [ -z "$PROFILE_PATH" ]; then
    echo "❌ Still no profile found. Exiting."
    exit 1
  fi
fi

echo "✅ Found profile: $(basename "$PROFILE_PATH")"

# ── Step 4: Encode everything ──────────────────────────────────────────────
echo ""
echo "🔐 Encoding credentials..."

CERT_B64=$(base64 -i "$EXPORT_PATH")
PROFILE_B64=$(base64 -i "$PROFILE_PATH")
ASC_KEY_CONTENT=$(cat ~/.openclaw/workspace/secrets/freefall/AuthKey_QD9VPLLQQ5.p8 2>/dev/null || echo "PASTE_P8_CONTENT_HERE")

# ── Step 5: Print GitHub secrets ───────────────────────────────────────────
echo ""
echo "=================================="
echo " ✅ DONE — Add these to GitHub Secrets"
echo " github.com/jamie323/freefall-app/settings/secrets/actions"
echo "=================================="
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret: ASC_API_KEY_CONTENT"
echo "Value:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$ASC_KEY_CONTENT"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret: BUILD_CERTIFICATE_BASE64"
echo "Value: (copying to clipboard...)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$CERT_B64" | pbcopy
echo "[Copied to clipboard ✅ — paste it into GitHub now, then press Enter]"
read -p ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret: P12_PASSWORD"
echo "Value: $P12_PASSWORD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret: BUILD_PROVISION_PROFILE_BASE64"
echo "Value: (copying to clipboard...)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$PROFILE_B64" | pbcopy
echo "[Copied to clipboard ✅ — paste it into GitHub now, then press Enter]"
read -p ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Secret: KEYCHAIN_PASSWORD"
echo "Value: $KEYCHAIN_PASSWORD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=================================="
echo " All done! Push to main to trigger"
echo " your first TestFlight build 🚀"
echo "=================================="
echo ""

# Clean up
rm -f "$EXPORT_PATH"
