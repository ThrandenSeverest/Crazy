#!/usr/bin/env bash
set -euo pipefail

# KayKit Adventurers 1.0, pinned to a known CC0 revision. Large binary models
# are fetched during CI/bootstrap instead of bloating this small source repo.
revision="672074b73ba276876a19e8816ecdc5241817ab47"
repository="https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0.git"
destination="assets/characters/kaykit"
mkdir -p "$destination"

if [ ! -f "${destination}/Knight.glb" ] || ! echo "60428e3abc09ba83e595d256e3af8c5c976b46cdae599f0802fc82b4a3445168  ${destination}/Knight.glb" | sha256sum --check --status; then
  checkout="$(mktemp -d)"
  git -C "$checkout" init --quiet
  git -C "$checkout" remote add origin "$repository"
  git -C "$checkout" fetch --quiet --depth 1 origin "$revision"
  git -C "$checkout" checkout --quiet FETCH_HEAD
  source_dir="${checkout}/addons/kaykit_character_pack_adventures/Characters/gltf"
  cp "${source_dir}/Knight.glb" "${destination}/Knight.glb"
  cp "${source_dir}/Barbarian.glb" "${destination}/Barbarian.glb"
  cp "${source_dir}/Rogue_Hooded.glb" "${destination}/Rogue_Hooded.glb"
fi

echo "60428e3abc09ba83e595d256e3af8c5c976b46cdae599f0802fc82b4a3445168  ${destination}/Knight.glb" | sha256sum --check
echo "cefc311a0e10c7858b6141f5ada7e33268727564fb8ac1347aab97d000669cc6  ${destination}/Barbarian.glb" | sha256sum --check
echo "93e6e25213009952276d9cf34f5d96a243767334c66f280db0433ddfabb91545  ${destination}/Rogue_Hooded.glb" | sha256sum --check
