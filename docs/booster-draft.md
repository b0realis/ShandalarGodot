# Booster Draft

Open **Options → Booster Draft → Card pool / Launch
draft**, or **Deck Builder → Deck → Booster Draft** (2026-10-27: in every
build — the Options entry is not limited to development builds). Everything runs in the
game; no Python script or terminal is needed. An ordinary deck you were
editing stays intact when you visit draft setup and return.

## Choose a pool and launch

**Card pool…** lets you check entire implemented sets or expand a set and
check individual cards. Each set lists every card it printed, reprints
included; a card in several sets is one choice. The basic lands are their own
group at the top. Search finds names and sets. All and None affect all
currently available cards, not just search results. **Save pool** remembers this
selection; Cancel leaves it unchanged. These choices do not restrict ordinary duels.
Original-skin and card-art ZIPs supply pictures, not additional playable cards.

Disabled or missing numbered packs cannot contribute to a new deal. Their
previously saved card choices are retained when editing the available pool and
return when those packs are enabled again. To remove such a choice permanently,
enable the pack, uncheck the card and save the pool.

Set the numbers of:

- **Boosters:** 15 cards each — 1 rare, 3 uncommon, 10 common,
  and 1 basic land.
- **Starter/tournament packs:** 60 each — 3 rare, 9 uncommon,
  26 common, and 22 basic lands.
- **Extra lands of each basic type:** the same number of Plains, Islands,
  Swamps, Mountains and Forests; all five must be eligible.
- **Extra random cards:** any eligible rarity, drawn without duplicates.

Choose a time limit of 1–1440 minutes and a save folder, then **Launch draft**.
Defaults are 3 boosters, 1 starter, no extras and 20 minutes. The setup allows
up to 12 of each pack, 30 extra lands of each type and 60 random extras.
It refuses an insufficient rarity sheet instead of quietly dealing fewer cards.

Each launch seeds the pack dealer from the operating system's random bytes,
not the clock or the duel's random state. Nonbasic cards do not repeat within
one pack; they may repeat across packs. Basic lands draw with replacement.
The eligible sets share rarity sheets: this is not a simulation of a particular
factory's sealed-product collation. Sheets use the game's canonical printed
rarity per card name. Legendary is not a rarity: an uncommon legend fills an
uncommon slot, even though the builder shows its purple L marker.

An animated pack opening precedes the real deck builder. **Skip opening** goes
straight to building; the timer starts then, not during the animation.
This is **sealed-style deck construction**, not a multiplayer pick-and-pass draft.

## Build against the clock

The familiar large-card builder, filters, stats, sideboard and keyboard controls
remain available. The countdown and Done button sit at the upper right, above
the cards. Menus and changing window focus do not pause the countdown. Only the
dealt quantities can be added, counting main deck and sideboard together.
Outside-deck imports, proxies, pool switching and extra deck slots are disabled.

**Done**, the builder's Save/Exit commands, expiry, or closing the window finishes
the session and freezes editing. An unfinished deck is saved too; the results
screen warns if it has fewer than 40 main-deck cards. Normal format restrictions
still apply when choosing a duel. This local practice mode is not a secure
tournament referee and does not claim to prevent modification of local files.

## Files and recovery

The default folder is **`user://decks`**, so the deck appears in the ordinary deck
collection. Browse or type an absolute custom folder; Default restores the normal
location. `Load deck` and the duel deck pickers read only `user://decks`, so the
setup screen says when the chosen folder is elsewhere — such a draft is a real
file that is opened with `Import deck` instead. The choice and event settings are
remembered. Existing files are not moved or deleted.

Each launch uses a fresh timestamp/random filename:

- `draft-….deck`: the exact main deck and selected sideboard, in native text format.
  New timed drafts include comment lines for the seed, pack counts, extras,
  time limit, SHA-256 fingerprint and a complete machine-readable replay recipe.
- `draft-….pool.json`: all dealt cards, pack contents, event settings and completion
  state, with the collation rule and pack shapes. This file is saved **before
  building starts**. Unused cards remain here; they are not silently added to
  the deck. Share this file, not the remembered eligible-card settings.

The deck is checkpointed every two seconds while building and saved again at
completion. Writes use a `.pending` file followed by replacement; an interrupted
write may leave that recovery file. A save error freezes editing and offers
**Retry save** or **Save to default folder**, keeping the in-memory deck until a
save succeeds. No success is reported while a save is failing.

On web, files live in browser storage, not an arbitrary desktop folder. The results
screen offers separate **Download deck** and **Download pool** buttons. Download
external copies before clearing site data. Native macOS rendering and automated
tests do not substitute for testing a browser download or a Windows/Linux build.

## Check a deck against its pool

In draft setup, choose **Verify saved deck…**, select the original `.pool.json`
and the submitted `.deck` (or `.dec`), then **Check deck**. The check is read-only.
It sums all copies in the main deck **and sideboard**, reports outside cards or
excess copies by name, and rejects malformed receipts or inconsistent pack/count
records. A passing membership check does not certify minimum deck size or other
format rules. Web's picker accesses the files saved in that browser.

For fair play, the organiser should retain the original pool file **before
deck building**, then compare the final submission against that retained copy.
A player can edit both local files or restart a draft; storing multiple copies
on the same player's machine does not prevent that. This is an audit aid, not
proof of honest random dealing, authenticated identity, or enforcement of the
time limit.

## Reconstruct a draft from its deck

New timed drafts embed everything needed to reproduce the deal: a 256-bit seed
stored as hexadecimal text, the exact eligible card names grouped by rarity,
pack counts, extra lands/cards, time limit, the versioned dealing algorithm and
fingerprints of both the deal and the recipe. A seed alone would not suffice:
different eligible-card settings would produce different packs.

In **Verify saved deck…**, choose the `.deck` and select **Reconstruct deck**.
No separate pool file is required. The report regenerates every pack, lists
all dealt cards and checks the submitted main deck plus sideboard. Paste the
judge's **pre-draft fingerprint** to also detect a substituted recipe. Without
that independent reference, the report explicitly says **Unanchored replay**.
Alternatively, **Check deck** compares against the judge's retained pool file
and requires its fingerprint to match the embedded recipe.

The original `.pool.json` contains the same recipe/fingerprint before building
starts. Retain it, or record its `recipe.fingerprint`, independently at that
point. Receiving a fingerprint only with the finished deck proves consistency,
not that the player accepted the first random deal. This does not prevent seed
searching, prove identity, enforce elapsed building time or authenticate a
player-run executable; an organised event still needs a trusted deal/commitment.

Native draft checkpoints, final saves and web downloads use identical metadata.
Ordinary native deck loading, saving, copying and Undo preserve the comments;
clearing to a new unrelated deck drops them. Keep the native `.deck` for judging:
conversion/export to another program's format may discard its comments. Older
drafts have no saved seed/eligible-sheet recipe and cannot acquire one
retroactively; use their original `.pool.json` for membership checks.

The replay algorithm is independent of Godot's random-generator implementation
and current card-pool settings. Its frozen specification and reference vector
are in [Draft replay v1](draft-replay-v1.md). Replay of card names is data-only;
the in-game membership parser still needs the corresponding card packs enabled.
A pool dealt with a numbered pack enabled is therefore checked only where that
pack is enabled: with the pack off, both **Check deck** and **Reconstruct deck**
name the pack they want rather than calling the pool corrupt, and the saved
`.pool.json` records the same list in `required_packs`.
