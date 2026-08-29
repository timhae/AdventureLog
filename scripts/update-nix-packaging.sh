#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for command in nix nix-update jq sed uv; do
    command -v "$command" >/dev/null || {
        printf 'Missing %s; run this script from nix develop.\n' "$command" >&2
        exit 1
    }
done

nix flake update

# These packages are maintained outside nixpkgs and track stable releases.
for package in django-allauth-ui django-geojson django-invitations django-resized; do
    nix-update --flake --version=stable "$package"
done

versions="$(nix eval --json .#adventurelog-backend.passthru.dependencyVersions)"
while IFS=$'\t' read -r package version; do
    # Only update existing direct requirements; transitive dependencies are ignored.
    sed -i -E \
        "s|\"${package}([<>=!~][^\"]*)?\"|\"${package}==${version}\"|I" \
        backend/server/pyproject.toml
done < <(jq -r 'to_entries[] | [.key, .value] | @tsv' <<<"$versions")

uv --project backend/server lock --upgrade

# Force fetchPnpmDeps to report and then record the current dependency hash.
old_hash="$(sed -n -E 's/^[[:space:]]*hash = "(sha256-[^"]+)";/\1/p' packages.nix | tail -n 1)"
[[ -n "$old_hash" ]] || {
    printf 'Could not find the frontend dependency hash.\n' >&2
    exit 1
}
sed -i "0,/hash = \"${old_hash}\";/s//hash = lib.fakeHash;/" packages.nix
build_log="$(mktemp)"
trap 'rm -f "$build_log"' EXIT
if nix build .#adventurelog-frontend --no-link >"$build_log" 2>&1; then
    printf 'Expected the frontend dependency hash check to fail.\n' >&2
    exit 1
fi
new_hash="$(sed -n -E 's/^[[:space:]]*got:[[:space:]]+(sha256-[^[:space:]]+).*/\1/p' "$build_log" | tail -n 1)"
if [[ -z "$new_hash" ]]; then
    sed -i "0,/hash = lib.fakeHash;/s//hash = \"${old_hash}\";/" packages.nix
    cat "$build_log" >&2
    exit 1
fi
sed -i "0,/hash = lib.fakeHash;/s//hash = \"${new_hash}\";/" packages.nix

nix flake check -L
