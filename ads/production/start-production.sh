#!/bin/sh
set -eu
# Install-time paths; no backend/player/video assets or remote control service.
exec /userdata/ads-production/ads-production-live --fullscreen "$@"
