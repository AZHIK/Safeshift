#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Corepack's global shim may not be writable. Use a user-local shim so Turborepo
# can locate the package manager binary.
if ! command -v pnpm >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  corepack enable --install-directory "$HOME/.local/bin" pnpm || true
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v melos >/dev/null 2>&1; then
  export PATH="$HOME/.pub-cache/bin:$PATH"
fi

if ! command -v node >/dev/null 2>&1; then
  echo "error: Node.js 24+ is required." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: Flutter SDK is required." >&2
  exit 1
fi

if ! command -v corepack >/dev/null 2>&1; then
  echo "error: corepack is required. Install Node.js 24+." >&2
  exit 1
fi

echo "==> Installing Node workspace dependencies"
corepack pnpm install

if ! command -v melos >/dev/null 2>&1; then
  echo "==> Installing Melos 7.8.0"
  dart pub global activate melos 7.8.0
fi

if ! command -v melos >/dev/null 2>&1; then
  echo "error: melos is not on PATH. Add \$HOME/.pub-cache/bin to PATH." >&2
  exit 1
fi

echo "==> Bootstrapping Flutter/Dart workspace"
melos bootstrap

echo "==> Done. Start the database with: pnpm db:start"
