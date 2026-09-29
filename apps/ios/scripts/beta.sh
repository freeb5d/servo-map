#!/usr/bin/env bash
# Ship the current checkout of the iOS app to TestFlight (`./scripts/beta.sh`), or run
# another fastlane lane with the same credentials (`./scripts/beta.sh metadata`).
#
# Reads the App Store Connect API key from 1Password through the service
# account (the values go straight into this process's environment; they never
# reach a file or the log) and hands them to fastlane. The key is the team's
# App Manager key, shared with kioku-ios: 02 Personal Production /
# "App Store Connect API Key - kioku-ios-ops".
set -euo pipefail
cd "$(dirname "$0")/.."

OP_ITEM="op://02 Personal Production/App Store Connect API Key - kioku-ios-ops"

ASC_KEY_ID="$(op read "$OP_ITEM/key_id")"
ASC_ISSUER_ID="$(op read "$OP_ITEM/issuer_id")"
ASC_KEY_CONTENT="$(op read "$OP_ITEM/private_key_base64")"
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_CONTENT
export ASC_KEY_IS_BASE64=1

exec fastlane "${@:-beta}"
