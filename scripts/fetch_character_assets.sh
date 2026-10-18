#!/usr/bin/env bash
set -euo pipefail

# KayKit Adventurers 1.0, pinned to a known CC0 revision. Large binary models
# are fetched during CI/bootstrap instead of bloating this small source repo.
revision="672074b73ba276876a19e8816ecdc5241817ab47"
base_url="https://raw.githubusercontent.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0/${revision}/addons/kaykit_character_pack_adventures/Characters/gltf"
destination="assets/characters/kaykit"
mkdir -p "$destination"

fetch_model() {
  local name="$1"
  local expected="$2"
  local target="${destination}/${name}.glb"
  if [ ! -f "$target" ] || ! echo "${expected}  ${target}" | sha256sum --check --status; then
    curl --fail --location --retry 3 --silent --show-error "${base_url}/${name}.glb" --output "$target"
  fi
  echo "${expected}  ${target}" | sha256sum --check
}

fetch_model "Knight" "60428e3abc09ba83e595d256e3af8c5c976b46cdae599f0802fc82b4a3445168"
fetch_model "Barbarian" "cefc311a0e10c7858b6141f5ada7e33268727564fb8ac1347aab97d000669cc6"
fetch_model "Rogue_Hooded" "93e6e25213009952276d9cf34f5d96a243767334c66f280db0433ddfabb91545"
