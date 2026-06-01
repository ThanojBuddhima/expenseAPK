#!/usr/bin/env bash
# Build release APK using JDK 17 without hardcoding paths in the repo.
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${JAVA_HOME:-}" ]] || ! java -version 2>&1 | grep -qE '"17\.'; then
  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
  for version in 17 21; do
    candidate="$(/usr/libexec/java_home -v "$version" 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
      export JAVA_HOME="$candidate"
      break
    fi
  done
  fi
fi

if [[ -z "${JAVA_HOME:-}" ]] || ! "$JAVA_HOME/bin/java" -version 2>&1 | grep -qE '"17\.'; then
  echo "JDK 17 is required. Install Temurin 17 and set JAVA_HOME, e.g.:"
  echo "  export JAVA_HOME=\$(/usr/libexec/java_home -v 17)"
  exit 1
fi

echo "Using JAVA_HOME=$JAVA_HOME"
flutter build apk --release "$@"
