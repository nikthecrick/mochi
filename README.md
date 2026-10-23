# RetroPet

A tiny tamagotchi that lives on your macOS desktop — retro pixel pet on the
outside, modern glass UI on the inside. Universal binary (Intel + Apple Silicon).

## What it does

- Hatches from an egg, then floats on your desktop, above all windows, on every Space
- Stats decay in real time (also while the app is closed): hunger / happiness / energy
- Feed, play, sleep; pat it with a click; drag it anywhere; right-click or the ⚙ button for settings
- **Feed it files** (drag & drop or “Feed with a file…”): bigger files = tastier, ears glow, and the file is moved to the Trash
- After **3 meals** it **grows legs** (sparkle moment) — then it rests like a cat, occasionally **trots across the screen** (really moves, with sniff pauses; the position sticks), and dangles/kicks its legs when you pick it up
- **Toilet loop**: files it eats go to the Trash — later it **poops a little pile**; click a pile to **restore the file from the Trash**, or “Clean toilet (empty the Trash)” in the menu
- **Breeds**: every pet hatches with random colors (Mint, Peach, Lavender, Sky, Sunny, Rose, Sage, Cocoa — body/shade/blush)
- **Incubation**: the egg takes ~15 min — the shell shows the **live CPU temperature** (real sensor via `ioreg` where available, else a load-based estimate) and hatches **faster when your Mac runs warm**; press **H** (after clicking the egg) to hatch instantly
- **Size grows with age**: starts tiny, grows to full size over ~a day (springy "is growing!" bounce + sparkles at milestones)
- **Chubbiness**: eating too much / not playing enough makes it visibly chubby (wider, squashed); playing burns it off
- **Evolution**: 3 meals -> **legs**, 6 -> **little arms** (waves hello), 12 -> **gadget: cool shades** + unlocks a **pixel pool** (its own little window — park it anywhere; the pet strolls over, **takes a dip**, gets out and carries on; remove it via its right-click menu)
- **Browser tabs as food**: drag a browser tab (or the address-bar icon, or a link) onto the pet — it closes the matching tab in Chrome/Safari/Edge/Brave/Chromium; Automation permission asked once A pooped tab comes back as a clickable `.webloc` link
- Faces: friendly `:3` resting smile + random expressions (looks around, winks, smug); `^ ^` when happy; frown only when actually sad; lip-lick when hungry; huge chomping mouth when a file is coming
- Ambient 8-bit jingles (every 10-20 s) + retro sound effects; both toggleable
- It really dies: ~4 h of total neglect -> RIP. A death note (`.txt` + tombstone `.png`)
  is left on your Desktop. Then: new pet or quit.
- Settings: show glass controls “on hover” or “on left-ear click” (click the ear to toggle)

## Build & run

```sh
./scripts/build.sh      # universal arm64 + x86_64 -> RetroPet.app
open RetroPet.app
```

Dev helpers (no bundle needed):

```sh
swift run RetroPet --smoke         # headless self-test
swift run RetroPet --dump-sprites  # ASCII preview of every sprite
swift run RetroPet --dev           # app with Dev menu (prepared features)
```

## Controls

| action | effect |
| --- | --- |
| click pet | pat (+happiness, hearts) |
| hover | stats + glass control bar |
| drag | move the pet (position is remembered) |
| right-click | full menu (feed/play/sleep/music/mute/rename/new/quit) |

## Assets (free libraries)

- **Press Start 2P** typeface — SIL OFL 1.1, from Google Fonts (`Assets/fonts`, license included)
- **Sounds** — CC0 by Kenney (kenney.nl): *Interface Sounds*, *Digital Audio*, *RPG Audio*,
  *Music Jingles (8-Bit)*. OGG -> WAV conversion via `afconvert`. Kept in `Assets/sounds`.

## Prepared for later (asked-for roadmap)

- **Borrow the pet** — a friend can care for your pet when you're busy.
  Format + export/import done (`BorrowManager`, `.retropet` JSON snapshot,
  menu items under `--dev`). TODO: lend-with-timeout UX, auto-return, care ledger.
- **Death means gone** — `GrimReaper.selfDestruct` is implemented but disabled.
  Enable the "app deletes itself" mode later with:
  `defaults write dev.tryouts.retpet.RetroPet RetroPet.selfDestruct -bool YES`
  (moves the `.app` bundle to the Trash on death, after leaving the note).

State lives in `~/Library/Application Support/RetroPet/pet.json`.