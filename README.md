# Mochi

*A tiny pixel bunny who lives on your Mac desktop — and has a whole life of their own.*

Mochi floats above all your windows, wanders across your screen, eats your files, dreams in
color, and might just steal your heart. Universal binary — runs natively on Apple Silicon & Intel.

---

## It begins with an egg

Mochi hatches from a little egg that sits on your desktop. The shell pulses and glimmers while
you wait. Keep your Mac warm — the egg hatches faster that way.

Once hatched, a tiny round bun appears. They're small. They're shy. And they're hungry.

---

## Taking care of Mochi

Mochi has needs — hunger, happiness, and energy — and they drift over time, even when the app
is closed. Keep them happy and something wonderful might happen.

| gesture | what it does |
|---|---|
| **click** | give a little pat |
| **hover** | peek at their stats + controls |
| **drag** | move them anywhere on screen |
| **right-click** | open the full menu |

---

## Feeding time

Drag **any file** onto Mochi — documents, images, music, whatever. Bigger files are tastier.
Their ears will glow, they'll make a happy face, and the file heads to the Trash.

You can even drag a browser tab straight onto them. It just works.

Meals have consequences. Keep feeding and watch what happens...

---

## Sweet dreams

When Mochi sleeps deeply, a dream appears — a little window of wherever their mind has wandered.
Pastel skies. Cosmic adventures. Cherry blossom waves. Each dream is unique and freshly painted.

---

## They think, too

If you've connected an AI model in settings, Mochi develops opinions. They might
pop up with a little speech bubble and say something completely unprompted.
Sometimes wise. Sometimes chaotic. Always Mochi.

---

## Growing up

Feed them, play with them, give them love — and they'll grow. New abilities unlock.
New accessories appear. The world gets a little bigger.

There's a lot to discover. Some of it surprises even us.

---

## Build & run

```sh
./scripts/build.sh      # universal arm64 + x86_64 → Mochi.app
open Mochi.app
```

Dev helpers (no bundle needed):

```sh
swift run Mochi --smoke         # headless self-test
swift run Mochi --dump-sprites  # ASCII preview of every sprite
swift run Mochi --dev           # app with Dev menu
```

---

## Breeds & colors

Every Mochi is born different — 8 possible color palettes: Mint, Peach, Lavender, Sky, Sunny,
Rose, Sage, and Cocoa. Body, shade, blush — all randomly yours.

---

## Sounds

Ambient 8-bit jingles play every now and then, plus little retro sound effects for life's
important moments. Toggle music and sound effects independently in the menu.

---

## Assets (free libraries)

- **Press Start 2P** — SIL OFL 1.1, from Google Fonts (`Assets/fonts`)
- **Sounds** — CC0 by Kenney (kenney.nl): *Interface Sounds*, *Digital Audio*, *RPG Audio*,
  *Music Jingles (8-Bit)*. Converted OGG → WAV via `afconvert`. Kept in `Assets/sounds`.

---

## State

Lives in `~/Library/Application Support/Mochi/pet.json`.

---

*take good care of them*
