# Working rules for Claude sessions

- **Branches:** when work starts by pulling from `testbranch`, push the results back to
  `testbranch`, not to the default branch, unless the user explicitly says otherwise.
- **Feature backlog:** `FEATURES.md` mirrors the "Features to add" and "Known bugs" sections of
  the "Tap & Hatch Alpha — Design Doc" (Claude Docs). Whenever one changes, update the other to
  match. A session without the Claude Docs connector updates `FEATURES.md` and says the doc needs
  the same change.
- **Checks before pushing:** `stylua --check src tests`, `selene src`, the luau-lsp type check,
  `python3 tests/run.py <path to luau>` and `rojo build` (see `.github/workflows/ci.yml`).
