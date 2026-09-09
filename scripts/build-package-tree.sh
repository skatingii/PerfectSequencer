#!/usr/bin/env bash
# Builds the Packages tree that `wally install` would produce, so PerfectSequencer
# can be dropped into a synced project before it is published to the registry.
set -euo pipefail

cd "$(dirname "$0")/.."

SCOPE="skatingii"
NAME="perfect-sequencer"
VERSION="0.1.0"
ALIAS="PerfectSequencer"
SIGNAL="sleitnick_signal@2.0.3"

OUT="dist/Packages"
PKG="${SCOPE}_${NAME}@${VERSION}"

if [ ! -d "Packages/_Index/${SIGNAL}" ]; then
	echo "error: Packages/_Index/${SIGNAL} is missing, run 'wally install' first" >&2
	exit 1
fi

rm -rf dist
mkdir -p "${OUT}/_Index/${PKG}"

cp -r src "${OUT}/_Index/${PKG}/${NAME}"
cp -r "Packages/_Index/${SIGNAL}" "${OUT}/_Index/${SIGNAL}"

cat > "${OUT}/_Index/${PKG}/Signal.luau" <<EOF


return (require(script.Parent.Parent["${SIGNAL}"].signal))
EOF

cat > "${OUT}/${ALIAS}.luau" <<EOF
local REQUIRED_MODULE = require(script.Parent._Index["${PKG}"]["${NAME}"])
export type SequencerEvent = REQUIRED_MODULE.SequencerEvent
export type TrackSequencer = REQUIRED_MODULE.TrackSequencer
return REQUIRED_MODULE
EOF

echo "built ${OUT}"
