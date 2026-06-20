# Haskell WASM Vomit Draft Editor

Modification of this repo: https://github.com/ori-livson/haskell-vomit-draft-editor

See that repo for an explanation of what a Vomit Draft Editor is.

But instead of serving the HTMX HTTP requests with a servant API - we do everything in the browser like so:
- We put all the Haskell HTML generating code in a `.wasm` file.
- Export equivalents to the HTTP endpoint handlers from the wasm.
- Redirect all HTMX calls to the wasm (with help from https://github.com/ernestmarcinko/htmx-serverless)
    
## Deployment

Deployment instructions combined in `deploy.sh`

## Creating the .wasm

Create `static/wasm-vomit-draft.wasm`

```bash
nix shell \
    --extra-experimental-features flakes\
    --extra-experimental-features nix-command \
    'gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org'

wasm32-wasi-cabal update  # only need to do once

cabal clean # required when cabal build done before this.

wasm32-wasi-cabal build -f wasm  # flag used to toggle foreign export ccall

cp $(find dist-newstyle -name "*.wasm" | tail -n 1) static/wasm-vomit-draft.wasm
```

## Setup home page

Create `site/index.html`

```bash
cabal clean -- required if wasm32-wasi-cabal build done before this
cabal run
```

Then add to `.cabal` file

## Testing the website

```bash
python3 -m http.server
```

### Troubleshooting 

If you get errors like
```
.../include/ffi/ffi.h:52:10: error:
     fatal error: 'os/availability.h' file not found
```

Do this.

```bash
unset CPATH
unset C_INCLUDE_PATH
unset LIBRARY_PATH
unset SDKROOT
unset PKG_CONFIG_PATH
```

```bash
cabal repl --ghc-option='-package Main'
```

```bash
$(wasm32-wasi-ghc --print-libdir)/post-link.mjs -i site/wasm-vomit-draft.wasm -o site/ghc_wasm_jsffi.js  
```

### Adding new modules

To help with cabal compilation and .vscode integration (e.g., hovering to view types), I've added the following helper:

To add a new module `X.hs` to `wasm-vomit-draft.cabal` and `hie.yaml` files, run:
```bash
./add_module wasm-vomit-draft X
```