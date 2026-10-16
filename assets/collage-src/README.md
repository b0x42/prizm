# README collage

Source for `assets/collage.png`, the feature image at the top of the main README.
`template.html` is the layout (dark background, header, four tilted windows, captions);
`capture.sh` grabs the app windows; `build.sh` renders the final PNG.

## Regenerate

1. Install the tools once: Chromium and ImageMagick (`brew install --cask chromium && brew install imagemagick`).
   Build the window-id helper: `swiftc winid.swift -o winid`.
2. Run Prizm normally and sign in to a demo vault with example data only (never a real vault).
   Keep the window the same size for all four shots, and click into the item list once so the selected row is blue.
3. For each shot, set the app up as below, then run `./capture.sh <name>`:

   | Name | Caption | Set up |
   |---|---|---|
   | `hero` | Verification codes | **Codes** selected, one login open so its Codes card shows |
   | `orgs` | Organisations & collections | Organization expanded with collections, sidebar scrolled to the top, one org item open |
   | `search` | Folders & search | **All Items**, search `devorg`, a result with a code open |
   | `types` | Every item type | A login that has a working code and an attachment |

4. Run `./build.sh`. It writes `assets/collage.png` (2400×1600).

Captures go to `shots/`, which is git-ignored. Check the result before committing:
no real data, no clipped sidebar, and no "Code unavailable" in the Codes card.
