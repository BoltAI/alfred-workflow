#!/bin/bash
# Packages src/ as build/BoltAI.alfredworkflow (a zip). Open the result to install it in Alfred.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
command rm -f build/BoltAI.alfredworkflow
/usr/bin/plutil -lint -s src/info.plist
(cd src && /usr/bin/zip -q -X -r ../build/BoltAI.alfredworkflow info.plist icon.png boltai.sh alfred.js)
echo "$(pwd)/build/BoltAI.alfredworkflow"
