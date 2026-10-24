# Ștefan

A fresh Godot desktop game, starting with a medieval Moldavian inspired main menu.
Select **Play** or press **Enter/Space** to open the empty black game screen.
Current version: **0.1.0**. No gameplay or saves yet.

## Run

Use **Godot 4.7.2** with its Compatibility renderer. Open `godot/project.godot`
and press F5, or run from the repository root:

```sh
# First checkout: import bundled assets once.
./godot/run.sh --headless --editor --import --quit
./godot/run.sh
```

The launcher finds Godot in Applications, Downloads or PATH. Set `GODOT_BIN`
if your executable is elsewhere. No Node.js installation or network is needed.

## Verify

Import assets once after a fresh checkout, then run the complete test:

```sh
./godot/run.sh --headless --editor --import --quit
./godot/run.sh --headless --script tests/test_menu.gd
```

The test checks title spelling/font coverage, version, initial keyboard focus,
visible focus styling, layouts at three sizes, real keyboard/mouse activation
and the empty black game scene. To capture actual GPU-rendered screens:

```sh
./godot/run.sh --script tests/capture_menu.gd -- /tmp/stefan-menu
```

The default window is 1280×800; the minimum is 1000×700. The title uses bundled
[Cormorant Unicase](https://github.com/google/fonts/tree/main/ofl/cormorantunicase),
licensed under the included SIL Open Font License. Button/version text uses a
system serif font. Vector artwork is original; its aurochs, star, rosette and
moon are an artistic Moldavian-inspired emblem, not a period reconstruction.

## Project notes

- [Lessons learned](docs/lessons-learned.md) and [historical research](docs/historical-research.md).
- [Preserved configuration](configuration/README.md) and [project rules](AGENTS.md).
- [Menu design](docs/superpowers/specs/2026-10-24-stefan-main-menu-design.md).
- [Validation](godot/VALIDATION.md) and [reset recovery archive](docs/RESET.md).

The working directory and existing GitHub origin remain `razes` to preserve
connections and Git history. Ștefan is the project name; `stefan` is its ASCII
spelling for technical identifiers. The previous browser, Swift/macOS and Godot
game implementations were removed. No remote rename, push or deployment is
part of this reset and first menu.
