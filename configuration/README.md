# Preserved configuration

`reference/` contains the previous build settings unchanged, including their old
Răzeș identifiers. These are inactive reference files, not runnable Ștefan projects.
Their source code, tests and assets were intentionally removed. Choose the new
implementation before promoting settings, manifests or dependencies back into use.

- `browser/`: npm manifest/lockfile, strict TypeScript, Vite/Vitest and Playwright settings.
- `godot/`: renderer/window settings, macOS/Windows/Linux export presets and engine discovery launcher.
- `macos/`: SwiftPM target settings and the local app packaging/signing recipe.

Root `.node-version` and Prettier preferences remain available. No dependencies
were installed. Old manifests retain their dependency versions for reproducibility.

Git metadata, remotes and ignored `.superpowers/` local state remain in place.
External account connections and installed tools are managed outside this repository.
No credentials were copied into this reference directory.
