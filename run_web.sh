#!/usr/bin/env bash
# Lance l'app sur Chrome en corrigeant le bug DWDS
# "Failed to establish connection with the web debug service: TimeoutException".
#
# Cause : Chrome >= 111 rejette la connexion WebSocket DevTools (403) si le flag
# --remote-allow-origins n'est pas passé au navigateur. On le force ici.
#
# Usage : ./run_web.sh [arguments flutter supplémentaires]
set -e
cd "$(dirname "$0")"
exec flutter run -d chrome \
  --web-browser-flag="--remote-allow-origins=*" \
  "$@"
