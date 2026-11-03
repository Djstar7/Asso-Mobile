#!/usr/bin/env bash
# Compile l'espace vendeur web pour le dossier public/vendor-web du backend.
#
#   scripts/build_vendor_web.sh [dossier de sortie]
#
# L'adresse visible reste /vendor : Laravel y sert index.html, dont les fichiers
# sont chargés depuis /vendor-web/.
set -euo pipefail

cd "$(dirname "$0")/.."
# Chemin absolu : avec un chemin relatif, Flutter ne dépose pas tous les fichiers.
OUTPUT="$(realpath -m "${1:-build/vendor-web}")"

flutter build web --release \
  --target lib/main_vendor_web.dart \
  --base-href /vendor-web/ \
  --dart-define=VENDOR_WEB=true \
  --output "$OUTPUT"

echo "Espace vendeur web prêt dans : $OUTPUT"
echo "À copier sur le serveur dans : public/vendor-web/"
