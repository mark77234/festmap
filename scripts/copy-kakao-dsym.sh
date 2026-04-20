#!/bin/sh
set -e
# Copy KakaoMapsSDK dSYM into the finalized archive dSYMs folder
SRC_DSYM="${PROJECT_DIR}/KakaoMapsSDK.framework.dSYM"
DSYM_DEST="${ARCHIVE_DSYMS_PATH:-${ARCHIVE_PATH}/dSYMs}"

if [ -d "${SRC_DSYM}" ]; then
  /usr/bin/ditto "${SRC_DSYM}" "${DSYM_DEST}/KakaoMapsSDK.framework.dSYM"
  echo "Copied KakaoMapsSDK.framework.dSYM to ${DSYM_DEST}"
else
  echo "warning: KakaoMapsSDK.framework.dSYM not found at ${SRC_DSYM}"
fi
