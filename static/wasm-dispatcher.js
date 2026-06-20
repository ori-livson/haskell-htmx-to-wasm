import {
  WASI,
  File,
  OpenFile,
  ConsoleStdout,
} from "https://cdn.jsdelivr.net/npm/@bjorn3/browser_wasi_shim@0.3.0/+esm";

// Set up WASI environment with stdin (empty file), stdout, and stderr piped to console
const wasi = new WASI(
  [],
  [],
  [
    new OpenFile(new File([])),
    ConsoleStdout.lineBuffered((msg) => console.log("[WASI stdout]", msg)),
    ConsoleStdout.lineBuffered((msg) => console.error("[WASI stderr]", msg)),
  ],
);

const wasm = await WebAssembly.compileStreaming(
  fetch("/static/wasm-vomit-draft.wasm"),
);

const inst = await WebAssembly.instantiate(wasm, {
  wasi_snapshot_preview1: wasi.wasiImport, // Wire WASI syscalls into the module
});

wasi.initialize(inst); // Run WASI reactor init (sets up memory/environment without calling _start)
inst.exports.hs_init(0, 0); // Initialize the Haskell runtime
inst.exports.appInit(); // Function defined in the wasm for redirectting stdout/stderror to console.log

// Troubleshoot what wasm functions are available to this JS.
// console.log("WASM EXPORTS:", inst.exports);
// console.log("WASM KEYS:", Object.keys(inst.exports));

// Function for calling exported wasm: CString -> IO CString fn
function callWithString(func, str) {
  const encoder = new TextEncoder();
  const decoder = new TextDecoder("utf8");

  const encoded = encoder.encode(str + "\0"); // Null-terminated string
  const ptr = inst.exports.callocBuffer(encoded.length); // Allocate zeroed buffer in WASM memory
  new Uint8Array(inst.exports.memory.buffer, ptr, encoded.length).set(encoded); // Copy string bytes into WASM memory

  const resultPtr = func(ptr);
  const resultBytes = new Uint8Array(inst.exports.memory.buffer, resultPtr);
  const length = resultBytes.findIndex((b) => b === 0); // Find null terminator to determine string length
  const result = decoder.decode(
    new Uint8Array(inst.exports.memory.buffer, resultPtr, length),
  );

  inst.exports.freeBuffer(ptr);
  inst.exports.freeBuffer(resultPtr);

  return result;
}

export function genHandler(endpoint) {
  /*Takes an endpoint like POST   /tick
    with form urlencoded:         boxes=a&boxes=&timeRemaining=3
    and creates a new endpoint:   /tick?boxes=a&boxes=&timeRemaining=3
    then calls the wasm:          dispatch(/tick?boxes=a&boxes=&timeRemaining=3)
  */
  return function (text, params, xhr) {
    const qs = new URLSearchParams(params).toString();
    const payload = endpoint + "?" + qs;
    const html = callWithString(inst.exports.dispatch, payload);
    return html;
  };
}
