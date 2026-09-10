#!/usr/bin/env python3
import pathlib
import re
import subprocess


def main():
    path = pathlib.Path("flake/packages/tree-sitter.nix")
    original = path.read_text()
    pattern = r'cargoHash = "sha256-[A-Za-z0-9+/]{43}=";'
    if len(re.findall(pattern, original)) != 1:
        raise RuntimeError("Expected exactly one tree-sitter cargoHash")

    # A real hash can reuse an older fixed-output result after the source changes.
    probe = re.sub(pattern, 'cargoHash = "sha256-' + "A" * 43 + '=";', original)
    try:
        path.write_text(probe)
        result = subprocess.run(
            ["nix", "build", ".#tree-sitter.cargoDeps", "--no-link", "-L"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
    finally:
        path.write_text(original)

    print(result.stdout, end="", flush=True)
    hashes = re.findall(
        r"hash mismatch in fixed-output derivation '[^'\n]*tree-sitter-cargo-deps[^'\n]*':"
        r"\s+specified:\s+sha256-[A-Za-z0-9+/]{43}=\s+got:\s+(sha256-[A-Za-z0-9+/]{43}=)",
        result.stdout,
    )
    if result.returncode == 0 or len(hashes) != 1:
        raise RuntimeError("Expected one tree-sitter cargo dependency hash mismatch")
    path.write_text(re.sub(pattern, f'cargoHash = "{hashes[0]}";', original))


if __name__ == "__main__":
    main()
