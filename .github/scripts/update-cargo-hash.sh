#!/usr/bin/env bash
set -euo pipefail

TREE_SITTER_NIX="flake/packages/tree-sitter.nix"

# Try building tree-sitter to check if cargoHash is still valid
echo "Building tree-sitter to verify cargoHash..."
if nix build .#tree-sitter 2>/dev/null; then
  echo "cargoHash is up to date"
  exit 0
fi

echo "Build failed, attempting to get correct hash..."

# Set cargoHash to lib.fakeHash to trigger hash mismatch
sed -i '0,/cargoHash = "sha256-[A-Za-z0-9+/]*=*"/s|cargoHash = "sha256-[A-Za-z0-9+/]*=*"|cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="|' "$TREE_SITTER_NIX"

# Build again and capture the correct hash from the error
BUILD_OUTPUT=$(nix build .#tree-sitter 2>&1 || true)
NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/]+=*')

if [[ -z "$NEW_HASH" ]]; then
  echo "ERROR: Could not extract new hash from build output"
  echo "$BUILD_OUTPUT"
  exit 1
fi

# Validate hash format strictly
if [[ ! "$NEW_HASH" =~ ^sha256-[A-Za-z0-9+/]{43}=$ ]]; then
  echo "ERROR: Hash format validation failed: $NEW_HASH"
  exit 1
fi

echo "Updating cargoHash to: $NEW_HASH"
sed -i "s|cargoHash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\"|cargoHash = \"${NEW_HASH}\"|" "$TREE_SITTER_NIX"

echo "cargoHash updated successfully"
