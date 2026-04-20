#!/bin/sh
set -e
# Usage: ./scripts/archive-with-dsym.sh /path/to/output.xcarchive
ARCHIVE_PATH="$1"
if [ -z "$ARCHIVE_PATH" ]; then
  ARCHIVE_PATH="/tmp/festmap-$(date +%s).xcarchive"
fi

# Run archive (using the shared 'festmap-archive' scheme which contains the post-action)
xcodebuild -project festmap.xcodeproj -scheme festmap-archive -configuration Release -archivePath "$ARCHIVE_PATH" archive

# Ensure dSYMs folder exists in the archive and copy the project's KakaoMapsSDK dSYM into it
mkdir -p "$ARCHIVE_PATH/dSYMs"
SRC_DSYM="${PWD}/KakaoMapsSDK.framework.dSYM"
if [ -d "$SRC_DSYM" ]; then
  /usr/bin/ditto "$SRC_DSYM" "$ARCHIVE_PATH/dSYMs/KakaoMapsSDK.framework.dSYM"
  echo "Copied KakaoMapsSDK.framework.dSYM into ${ARCHIVE_PATH}/dSYMs"
else
  echo "warning: KakaoMapsSDK.framework.dSYM not found at ${SRC_DSYM}"
fi

echo "Archive complete: $ARCHIVE_PATH"
