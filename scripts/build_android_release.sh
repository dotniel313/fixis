#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter no está instalado o no está en PATH." >&2
  exit 1
fi

if [[ ! -f .env ]] || ! grep -q '^SUPABASE_URL=https://' .env ||
   ! grep -q '^SUPABASE_ANON_KEY=.' .env; then
  echo "Falta .env con SUPABASE_URL y SUPABASE_ANON_KEY del proyecto Fixis." >&2
  exit 1
fi

if [[ ! -f android/key.properties ]]; then
  echo "Falta android/key.properties con la clave de subida de Android." >&2
  exit 1
fi

for property in storeFile storePassword keyAlias keyPassword; do
  if ! grep -Eq "^${property}=.+" android/key.properties; then
    echo "Falta ${property} en android/key.properties." >&2
    exit 1
  fi
done

flutter pub get
flutter analyze
if [[ -d test ]] && find test -name '*_test.dart' -print -quit | grep -q .; then
  flutter test
fi
flutter build appbundle --release

bundle=build/app/outputs/bundle/release/app-release.aab
if [[ ! -s "$bundle" ]]; then
  echo "No se encontró el Android App Bundle de publicación." >&2
  exit 1
fi

echo "Bundle firmado: $bundle"
shasum -a 256 "$bundle"
