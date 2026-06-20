#!/usr/bin/env bash
set -e

GREEN='\033[0;32m'
NC='\033[0m' # No Colour

log() { echo -e "${GREEN}==>${NC} $1"; }

log "Setting up nix shell and building..."

nix shell \
  --extra-experimental-features 'flakes nix-command' \
  'gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org' \
  --command bash -c '
    GREEN="\033[0;32m"
    NC="\033[0m"
    log() { echo -e "${GREEN}==>${NC} $1"; }

    unset CPATH
    unset C_INCLUDE_PATH
    unset LIBRARY_PATH
    unset SDKROOT
    unset PKG_CONFIG_PATH

    log "Updating wasm32-wasi-cabal package repos"
    wasm32-wasi-cabal update

    log "Cleaning up dist-newstyle"
    cabal clean

    log "Building wasm"
    wasm32-wasi-cabal build -f wasm

    log "Copying site/static/wasm-vomit-draft.wasm"
    cp $(find dist-newstyle -name "*.wasm" | tail -n 1) site/static/wasm-vomit-draft.wasm
  '

log "Building and running site generator"
cabal clean
cabal run

log "Hosting site & static folders on port 8000"
python3 -m http.server