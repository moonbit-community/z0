# z0

An SMT solver (planned to be) compatible with Z3.

## Status

CDCL(T) + quantifier-free Bool+EUF subset

## CLI

The CLI supports the wasm and native backends. The default backend is wasm.

```sh
moon run src/shell --target wasm -- input.smt2
moon run src/shell --target native -- input.smt2
```

Use `--help` to print usage. File or SMT2 errors return exit code 1.
Wasm builds run with `moonrun` from the installed MoonBit toolchain.

```sh
moon test --target all
moonx moonbit-community/mooncram@0.0.6 test tests --target wasm --timeout-ms 120000
moonx moonbit-community/mooncram@0.0.6 test tests --target native --timeout-ms 120000
```
