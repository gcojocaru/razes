# Ștefan main menu validation — 24 October 2026

Godot 4.7.2.stable.official.ed1daf0bf, macOS, Apple M4, Compatibility renderer.

- Asset import and the full headless menu test pass: Romanian Ș glyph, title,
  settings-driven v0.1.0, initial Play focus, focus style, three layout sizes,
  Enter/Space activation, mouse activation and a completely empty black game scene.
- Actual GPU captures of the 1280×800 window, minimum 1000×700 window and blank
  game screen were inspected. Corrected the version position to clear the frame.
- The initial Uncial Antiqua font lacked Ș; replaced it with bundled Cormorant
  Unicase. The test asserts direct glyph coverage, so system fallback cannot
  silently mask missing Romanian support.
- Mouse test events use viewport-local coordinates, avoiding duplicate scaling
  in the input injection path when testing resized windows.

Captures are local artifacts in `/private/tmp/stefan-menu/`; regenerate with the
README command. The capture script activates the real Play button through mouse
input. No screenshots or generated engine caches are committed.

Restricted execution can report macOS certificate/per-user-directory access
errors before the passing test; normal engine execution is used for the final
verification and graphical captures. The app does not use networking or save
state.

Not checked: Windows/Linux execution, Intel/minimum macOS hardware, screen-reader
support, exports, signing or notarization. System button/version fonts may vary
across platforms. Historical fidelity of the ornamental style is not established.
