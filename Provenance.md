# Provenance — where everything in this project came from

This project reimplements MicroProse's 1997 *Magic: The Gathering* (and its
*Duels of the Planeswalkers* expansion) in GDScript on Godot 4.7. Almost
nothing here is invented. Nearly every behaviour, string, number and pixel
is traceable to a source, and this file is the register of those sources —
what each one is, how much authority it carries, and the rules for reading
it that this project learned the hard way.

## Why we are building it

> This project is a love letter to MicroProse MTG: to preserve that special
> 90s Shandalar feeling — the feel of playing early Magic, up to Fourth
> Edition, Alliances, and maybe Fifth — while still going for
> quality-of-life improvements, a modern spin on the gameplay, and the
> tools to go with it.
>
> The key is in the limitations. A specific, finite spell library is
> something you can get creative with, instead of losing time to an
> ever-widening card pool and its obsolescence. It can be fun, it can be
> creative, and — would you believe it? — it can even be relaxing. :)
>
> All the best to the players, and to the community for its help with the
> development. Good luck and good health to all!
>
> — b0realis

That paragraph is the design brief, and it settles arguments this codebase
actually has. **The limitation is the feature.** A closed pool of roughly
900 early cards is not a shortfall to be grown out of — it is the thing
that makes the game creative and finite and, yes, restful. So when a
decision is between fidelity to 1997 and a modern convenience, fidelity
wins unless the convenience is *labelled* as ours (`[QoL]`) and can be
switched off. That labelling is not bureaucracy; it is how the 90s feeling
survives contact with modern expectations.

## The three tiers, and which wins

When two sources disagree — and they do — this is the order of authority.

**Tier 1 — the 1997 artefacts themselves.** What the original shipped: its
string tables, its help file, its printed manual, its executable. If one of
these says something, it is what the game did.

**Tier 2 — the decompilation.** Machine-faithful C recovered from the 1997
binary. Outranks any community reimplementation for questions of *how the
original actually behaved*, because it is the original, read back.

**Tier 3 — reimplementations and continuations.** Manalink, s30, mage-go.
Excellent engineering and often the fastest way to understand a system, but
every one of them has made changes of its own. Useful as a guide, never as
proof. An `[s30]` tag in `docs/duel-todo.md` marks a feature the 30th
Anniversary remake added that the 1997 game did not have — labelled, never
silently mixed in.

---

## Tier 1 — the original

| Source | Where | What it settles |
|---|---|---|
| **The printed manual** (1997, MicroProse) | owner's scan, not in this repo | The primary authority for anything the player reads. Duel material is ch. 8 (pp. 59-106, the rules), ch. 9 (pp. 107-132, the screen), the Glossary (pp. 159-186), and the Sequence-of-Play appendix (pp. 187-194). Cited as **manual p.N** using PRINTED page numbers (`printed = PDF page − 6` in the owner's scan). It is what proved the original enforces **Fifth Edition** rules (p.108). |
| **`Duel.hlp`** — the game's own shipped help | `../shandalar-src/` | The "Dueling Help" the manual points at. Same authority as the manual, and more specific about the screen. Topics are cited by name (**Territory**, **Duelist's Face**, **Play or Draw Rule**). It is the reason the Combat Bar has seven icons and not the five the printed manual claims. |
| **`Program/UIStrings.txt`**, **`Program/promptsX*.txt`** | `../shandalar-src/Program/` | Every string the player sees, by tag (`@DIALOG_MULLIGAN`, `@PROMPT_PAYUPKEEP`, `@MENU_TERRITORY`). Cited as `UIStrings.txt:499`. **Read the rules below before grepping these.** |
| **`Advstrings.txt`** — the ADVENTURE's string table | `../shandalar-xp/MagicTG/` (1997-05-12), and `../s30/assets/text/` | Registered **2026-09-03**, and it settles things nothing else can. `@PLAYERNAMES` (count line `14`) names the fourteen player portraits IN SHEET ORDER — tied to the art by the decompilation, which indexes one variable into both the name table and the sprite (`MAGIC.EXE` entry `0047b899`; `symbols.csv` has the fourteen literals at `0x526944` "Melody Whisp" … `0x5269ec` "Keleena"). It also carries `@DIFFICULTYLEVELS`, `@WORLDMAGIC_NAMES`/`_EXPLAINS`, `@DUNGEON_NAMES`, `@LAIR_NAMES`, the city-name generator, `@WIZARDNAMES`, `@AMULETNAMES` and the enemy-type table — most of M5's vocabulary, and **s30 itself does not read it**. The MagicTG and s30 copies align; `shandalar-src`'s is offset +2 lines. |
| **`s30/assets/text/Uistrings.txt`, `Menus.txt`, `CueCards.txt`** | `../s30/` | The genuine 1997 copies of these three tables. `Uistrings.txt` joined the list on **2026-09-02**: `Program/UIStrings.txt` carries a handful of Manalink modernisations (`Reach` for the 1997 **`Web`**, `View exiled cards` for `View the out-of-play cards`, an expanded `@LANDWORDS`, an added `@GROUPMOVE`). The two are line-for-line aligned **to line 1183**, `Program − 40` after it, so existing citations are safe — see the rules. |
| **`Readme.txt`** — MicroProse's own, *"Duels of the Planeswalkers"* Version 3.0, **14 January 1998** | `../shandalar-xp/MagicTG/Readme.txt`, and byte-identical (md5 `660aa64926f1f293e2c38f7dfa750955`) in `../s30/assets/text/` | Registered **2026-09-03**. The nearest thing to a transcript of the printed manual's screen chapter that exists locally — it even points at *"pages 116-118 of the manual"*. It is what settles the AUTO-ADVANCE: *"If you do not put a Stop (the red marker) on a phase, play will bypass that phase without bothering to ask you if you want to use optional effects (a Brass Man's untap or Land Tax, for example)"* (`:70-80`) and *"Otherwise, the game will only stop at your upkeep phase for MANDATORY effects"* (`:645-659`) — an unstopped phase is bypassed on your own turn, and a mandatory effect stops it anyway. It also records a SECOND marker colour the other sources never mention: *"Green phase stoppers have ben [sic] removed from the multiplayer portion of the game"* (`:637-643`), i.e. the left-click `Run to` destination was drawn green and the `Mark` Stop red. Two trees that travelled separately agreeing byte for byte is the same witness that vouches for `Sound/`. |
| **`Master.csv`** and **`Info.csv`** — the 1997 CARD DATABASE ITSELF | `../shandalar-xp/MagicTG/` (both **1997-08-14**) | Registered **2026-09-04**. `Master.csv` is `ID,Card Name,Type Description,Artist Name,Rule Text,Quote`, 1 251 rows, and it is the authority on **how the original wrote a card's rules text** — including the fact that it wrote the mana and tap symbols INLINE, escaped with a pipe: `0230,Sol Ring,Artifact,Mark Tedin,\|T: to add \|2 to pool - Interrupt`. 338 rows carry a tag; the vocabulary is `\|X`, `\|0`..`\|9`, `\|W\|U\|B\|R\|G` and `\|T`, which is exactly the nineteen cells of `Cardart/Manasymbols.pic` and nothing more. **`\|T` is the commonest of them (204 rows)**, and tap is never part of a mana cost — so those symbols can only have been drawn in the rules-text body. `Info.csv` is the other half: the CASTING COST as a packed six-digit numeric field (`000001` = Sol Ring, `010000` = Birds of Paradise), NOT a symbol string — which is why the original's renderer has two separate paths, one synthesising tags from those numbers for the cost cluster and one parsing them out of the text. **The rules text this project displays is Scryfall's, not this file's** (for the same reason the artist credit is: our art is Scryfall's for the same printing), so `{R}`-style braces are OURS — but `Master.csv` settles what the original DID with them. |
| **`Magis___.ttf`** — the MagicSymbols face | `../shandalar-xp/MagicTG/` (**1996-07-30**) | *"MagicSymbols … © 1994 by Wizards of the Coast, Inc. Version 1.7. Originally based on Plantin"*. Its cmap holds `W U B R G`, `T`, `X` and `0`-`9` in two sizes, and `Duel.hlp`'s own font table declares it — which is how the help file drops a tap or a black-mana glyph into the middle of a sentence of quoted card text (**Activation Cost** topic). It is the type half of what `Manasymbols.pic` is the bitmap half of. |
| **Original art** (`.PIC`/`.SPR`) | the owner's own install | Never in this repo. `tools/import_original.py` runs against the player's copy and writes a local skin. |
| **`MagicTG/`** — the owner's own 1997 install, off a Windows XP machine | `../shandalar-xp/MagicTG/` (zips kept in `../shandalar-xp/incoming/`) | **Arrived 2026-09-03**, and it is the first genuinely 1997 TREE this project has had rather than 1997 files carried inside a later one. 4 215 files; the ones that matter are dated **1996-10 to 1997-11**: `Faces/*.pic` (1996-10-10), `Advfac64.pic` (1996-10-21), `16faces.spr` (1997-01-09), `Duelart/Cointoss_{Heads,Tails}.avi` (**1997-01-28**), `Advblocks.txt` (1997-04-16), `Advstrings.txt` (1997-05-12), `Duel.hlp` (1997-11-11). **It is a MIXED tree** — 1 287 files are dated 2009 and 976 are 2001, i.e. later patches dropped into the same directory — so a file's DATE decides its tier, exactly as it did for `Decks.zip`. Where a 1996-97 file here disagrees with `../shandalar-src`, this one wins. |

### The coin-toss codec — a Tier-1 file correcting a Tier-3 measurement

`tools/import_original.py` stated flatly that "the 1997 video codec is
Indeo Video 4.1", read out of `magvid.dll`'s hard-coded `iv41` literals and
confirmed across all 69 AVIs of a **Manalink** install. The owner's own
1997 files say otherwise for the one that mattered: `Cointoss_Heads.avi`
and `Cointoss_Tails.avi` (1997-01-28) declare **`CRAM`** — Microsoft Video
1, a 1992 codec every ffmpeg and GStreamer build decodes. The DLL was
right about what it could play; the survey was right about the files it
saw; the general claim was wrong, and it had stood since the importer was
written. The coin toss is now imported and plays (61 frames, 320x240, 15
fps, per face).

**The rule it illustrates:** a measurement taken across a Tier-3 tree
describes that tree, not the original. Say which tree it was measured on.

### The `.PIC` format, and the three counts of enemy faces

**The format**, ported into `tools/import_original.py` on 2026-09-03 from
`mp_pic_tools` (Tier 2) and verified byte for byte against it on 63 files
of the owner's install. A PicV3 file is a chain of
`<2-byte tag><uint16 length><data>` blocks: `M0`/`M1` is a palette
(`first`, `last`, then RGB triples), `X0`/`X1` is the image (`uint16`
width, `uint16` height, `uint8` maximum LZW code width, then the data).
The image block is always last and its `length` is sometimes an
overflowed `uint16`, so it runs to the end of the file. The data is LZW
around RLE — RLE `0x90 <count>`, `0x90 0x00` a literal — and the LZW is
**not** the textbook one: codes are packed low bit first, the code width
follows a FIXED schedule (9 bits for 256 codes, 10 for 512, 11 for 1024,
then a full reset) rather than growing when the table fills, and the
dictionary's first free slot is **257**, not 256. A decoder that gets any
of those three wrong produces static, not a picture — which is why the
port's real check was a contact sheet somebody looked at.

**Image and mask halves, and the polarity rule proved.** The enemy faces
are 276x170 = a 138-wide picture beside a 138-wide mask. This file
already warned that mask polarity is inconsistent across the asset set;
these files are the proof, in one directory: every `Faces/*.pic` uses
**255 = transparent**, and `Face.pic` beside them uses **0 = transparent**.
The importer therefore MEASURES polarity — the majority value on the
one-pixel border is the transparent one — instead of assuming it. The
mask also carries real information: it is not the same as "index 0",
because `020.pic` has 55 opaque index-0 pixels and `054.pic` 219, plus 74
drawn pixels the mask removes.

**THE THREE COUNTS — 57 files, 55 names, 66 s30 PNGs — RECONCILED
2026-09-03.**

* `MagicTG/Faces/` holds **57** files but **55** pictures: `000.pic` is
  byte-identical to `001.pic` and `056.pic` to `055.pic`. They are
  end-caps, and what they cap is a **ONE-BASED** table — `001.pic` is
  `@DECKFACES` entry 1 (Witch), `055.pic` entry 55 (Uber Villain, whom
  the adventure calls **Arzakon**).
* That alignment is established, not guessed. s30 ships all 55 as named
  PNGs (`assets/art/rogues/MPS_*.png`, 138x170 — the picture half of
  these very files, palette-reduced). Matching each PNG's
  transparent-pixel set against each `.pic`'s pairs **all fifty-five**
  one-based with no collisions and nothing left over. Two independent
  tables agreeing on 55 rows, with the art itself as a third witness.
* s30's **66** `rogues/*.png` are **not the same 66** as anything in the
  install, and the matching number is a coincidence. Fifty-five of them
  are `MPS_*` and are the picture half of these very `Faces/*.pic`,
  palette-reduced; one, `Face.png`, is 137x169 and is `Face.pic`, the
  player's Facemaker face, not a rogue at all; the remaining **ten**
  (`Chunk`, `Cutiepie`, `Desdemona`, `Greenie`, `Lance`, `Lizzy`,
  `Lumpy`, `Medusa`, `Ophelia`, `Splinter`) match NOTHING in the owner's
  1997 tree, wear a visibly different and more painterly style, and are
  named by no 1997 table. They are s30's own (Tier 3).
* There IS a larger MicroProse set, and it is `MagicTG/Exp1art/Rogues/` —
  the *Duels of the Planeswalkers* expansion's art directory,
  `Rogue01.pic`..`Rogue72.pic` with six numbers absent = **66** files
  (a second coincidence of count). **Its dates and its md5s tell the
  same story twice.** Fifty files are dated 1996-10-10 and are
  byte-identical to `Faces/` — forty-six at their own slot number and
  four moved to new slots 67-70 (`Faces/018` -> `Rogue67`, `031` ->
  `68`, `036` -> `69`, `044` -> `70`). The other sixteen are dated
  1997-08-22 to 1997-09-04: five REDRAW base slots 10, 15, 24, 39 and 42
  (Crusader, Seer, Enchantress, Centaur Shaman, Centaur Warchief), and
  **eleven are new faces `Faces/` does not have** (`Rogue56`, `57`,
  `58`, `60`, `61`, `63`, `64`, `65`, `66`, `71`, `72` — a fairy, a
  vampire in evening dress, a skeleton, a turbaned mage). The md5
  partition and the date partition agree exactly, which is the check.
  **Those eleven have no name in any 1997 table**, so the expansion set
  is NOT imported: naming it would mean inventing names.

**`Face.pic` is a fifteenth face, not a copy of one of the fourteen.**
Checked because it was assumed to be the chosen `16faces` frame written
back out. It is what `Facemaker.exe` writes — a face composed from the
part layers in `Faceart/Fb1..Fb17.spr` — and this install's copy (1996-10-18,
MicroProse's own) matches no sheet frame: it wears frame 7's body under a
different head and differs from that closest frame in 5 972 of 23 153
pixels. **So the honest local portrait total is 70**: 14 player + 55
enemy + 1 Facemaker face. On a player's own install that last one is
whatever face they made.

### The audio — surveyed 2026-09-03, and NOT ONE SOUND FILE IS DATED 1997

The owner's install arrived with its timestamps intact, so for the first
time the audio could be dated rather than assumed. The answer is
uncomfortable and it is worth writing down once:

**In `../shandalar-xp/MagicTG/`, every `Duelsounds/*.wav` (72 files),
every `Sound/*.wav` (91) and `Statscrn.wav` is dated 2009-03-03.** So are
eleven of the twelve `Manalink/Sounds/`; the twelfth, `Taunt.wav`, is
2001-08-23. The 2009 stamp is the Manalink patch that overwrote the lot.

**The only 1996-97 audio in that tree is:**

| File | Date | What it is |
|---|---|---|
| `autoplay/Button.wav` (1 732 B) | 1996-06-13 | the CD's Windows AutoPlay shell, not the game |
| `autoplay/Menu.wav` | 1997-08-08 | the same shell |
| `autoplay/Click.WAV` | 1997-08-31 | the same shell |
| `Duelart/Cointoss_{Heads,Tails}.avi` | 1997-01-28 | 4.07 s of 22 050 Hz 8-bit mono PCM **inside the movie**; `Toss.wav` is 3.93 s and shares only part of it (below) |
| `Mtgend.avi` | 1997-02-19 | the ending movie's soundtrack, 8-bit stereo PCM |
| `Exp1art/WinSealedTournament.avi` | 1997-08-31 | IMA-ADPCM stereo |

The 55 `Statwin/*.AVI` (1996-09 to 1997-01) carry **no** audio stream.

**That does not make the sounds fake, and here is the evidence that they
are not.** Of the 91 files in `Sound/`, **71 are byte-identical** to the
independently distributed Manalink 3 tree's copies — `Dueltune.wav`,
`Winduel.wav`, `Loseduel.wav`, `Wingame.wav`, `Tmplmus1.wav` and the five
castle beds among them. Two trees that have travelled separately for
years agreeing byte for byte on 71 files is the strongest witness
available that those bytes are MicroProse's. **Only the twenty
`LocMusN.wav` differ**, and `Duelsounds/` differs entirely.

**Three masterings, no original — which is what `Grey.wav` was.** That
file exists three times locally, all 144 464 bytes, all 22 050 Hz mono
16-bit, and all three md5s different. Measured rather than guessed, they
are ONE recording at three gain stagings:

| Copy | Peak | What it is |
|---|---|---|
| `shandalar-src/Duelsounds/` | 13 044 = exactly **−8.0 dBFS**, and the same constant across most files | Manalink 3's live folder, peak-normalised |
| `shandalar-src/Program/DuelSounds/` | 18 426 = **−5.0 dBFS** | the same waveforms **+3.0 dB** (×1.4125): 11 files identical, 73 scaled |
| `<install>/Duelsounds/` (2009) | 18 240 on `Grey`, not constant | a further remaster that is **not** a linear gain — ×1.77 on loud samples but ×1.87 at the peak, i.e. a limiter — and 18 of the 72 are additionally block-padded to a 512/1024-byte boundary |

None of the three is provably 1997. **The importer therefore does not try
to pick the "real" one: it picks the folder the GAME reads** (`DuelSounds/`
and `Sound/`, the paths `windows.c:1228` and `deckdll.cpp:2047` build),
falls back to `Program/…`, and prints the date of every file it took.
What a player's own copy plays is what they get.

**s30 ships the 2009 masters too**, which is a fourth witness and a useful
cross-check. Decoding its `assets/audio/sfx/*.ogg` back to 22 050 Hz mono
gives PCM lengths that match the 2009 files EXACTLY and the
`Program/DuelSounds` ones not at all — `card_draw` 66 560 = `Draw.wav`,
`damage` 76 800 = `Damage.wav`, `counter` 46 080 = `Counter.wav`,
`land_play` 23 552 = **`Tap.wav`**, `click` 75 226 = **`Button.wav`**,
`cast` 87 124 = **`Summon.wav`**, `creature_death` 75 776 = **`Kill.wav`**.
The last four are the interesting ones: they are s30's own cue mapping,
readable from the byte counts, and two of them disagree with ours (see
`docs/ROADMAP.md`, "The audio pass").

**The one place a 1997-dated file can be held against a 2009 one, and
what it says.** `Cointoss_Heads.avi` (1997-01-28) carries 4.07 s of PCM;
`Toss.wav` (2009) is 3.93 s. Cross-correlated sample by sample, one
window of about 0.37 s matches strongly and at a stable offset
(**r = 0.62** at −1951 samples, and 0.64 against both `shandalar-src`
copies at the same offset), while unrelated controls — `Sound/Dice.wav`,
`Duelsounds/Draw.wav` — sit at **r = 0.00-0.05**. The rest of the two
files does not match. So the coin movie's soundtrack and the duel's
`Toss.wav` **share material but are not the same recording**: consistent
with both being built from the same coin foley in 1997, and NOT proof
that the 2009 wav is bit-for-bit the 1997 cue. It is the closest thing to
a dated witness the local files allow, and it is a lead somebody can
settle by ear.

**The rule this adds to the ones above:** *a file's date is Tier-1
evidence and it is free — read it before claiming a file is the
original's.* A previous pass imported an install's `Duelsounds/` as
though it were 1997 material and had to restore 57 files by hand. The
dates were on disk the whole time.

### The shell screen's audio — surveyed 2026-09-04: THERE IS NO TITLE MUSIC

The owner's playtest asked for *"a suitable soothing music at the main
menu"*, and the first question was whether the 1997 game already had one.
It does not, and the negative is worth registering because it is the kind
of claim somebody will otherwise re-derive every year.

**Where the shell lives.** The shell screen — the front end with the five
pages — belongs to `Magic.exe`, not to the adventure. It registers its own
window class (`wndproc_MagicShellClass`,
`shandalar-src/src/Magic-trace.c:4124`, entry `4CC770`), loads its art out
of `\ShellArt` (`%s\WINBK_ShellScreen16.bmp`, `%s\WINBK_ShellBox16.bmp`
and the five `%s\WINBK_ShellSphereAnimation16-%d.bmp` frames — all
`Shellart/` files dated **1997-08-30 to 1997-10-07** in the owner's
install, so the screen itself is genuinely 1997), and names its pages with
`@SHELLSCREEN_DUEL` / `_TOOLS` / `_METAGAME` / `_HELP` / `_RECORDS`.

**Its entire audio vocabulary is one-shots.** The only sound table that
program has is the 68-entry `DuelSounds/` name array at
`shandalar-src/src/functions/windows.c:1181-1266`, named in
`src/defs.h:2179-2290`. Seven of its entries are the shell's:
`WAV_SHELL_LOSEDUEL` (44), `WAV_SHELL_WINDUEL` (45),
`WAV_SHELL_SHANDALAR` (60), `_TOOLTIME` (61), `_HELPME` (62),
`_HALLOFRECORDS` (63), `_DUELMENOW` (64). The last five map ONE-TO-ONE
onto the five `@SHELLSCREEN_*` pages, and measured off the owner's own
files (`Duelsounds/Shell_*.wav`, 22 050 Hz 16-bit stereo) they are

| cue | length |
|---|---|
| `Shell_Duelmenow` | 2.78 s |
| `Shell_Shandalar` | 5.25 s |
| `Shell_Tooltime` | 5.71 s |
| `Shell_Hallofrecords` | 5.75 s |
| `Shell_Helpme` | 6.09 s |
| `Shell_Loseduel` | 10.25 s |
| `Shell_Winduel` | 11.97 s |

— page stingers and two result cues, not a bed.

**And the beds are all in the OTHER exe.** Every looping-bed literal in
the original is in `Shandalar.exe`, the adventure: `x:sound\dueltune.wav`,
`x:sound\locmus0..19.wav`, `x:sound\tmplmus1.wav` and
`x:sound\[bgruw]castle.wav`. `Magic.exe` carries **no `music` string, no
`sound\` path and no bed filename at all** — its only music-shaped
literals are `shell_loseduel.wav` and `shell_winduel.wav`. (Note the
naming: today's `Magic.exe` is the DUEL+shell program and today's
`Shandalar.exe` is the adventure, which is what earlier entries in this
file call `MAGIC.EXE`. The literals are how you tell them apart.)

**Nor is it CD audio or MIDI.** `CdTools.dll` (1998-03-24) is imported by
`Shandalar.exe` only and exports `CheckOriginalCD`, `CheckSotaCD`,
`CheckDoPCD`, `IsCDDrive`, `QueryCancelAutoPlay`, `Autoplay_ShutDown`,
`Autoplay_Restore` — disc presence and AutoPlay suppression, not redbook
playback. A full audio inventory of the owner's install finds **no `.mid`,
`.rmi`, `.xmi`, `.cda`, `.mp3` or `.ogg` anywhere**, and the only `.wav`
outside `Sound/` and `Duelsounds/` are `Statscrn.wav`, the twelve
`Manalink/Sounds/` network cues, and the three `autoplay/` files — which
are the CD's Windows AutoPlay shell and not the game (already recorded
above).

**So: a silent shell with spoken/stinger page cues.** Anything this
project plays on its title screen is `[QoL]` and must be labelled so.
`game/main.gd`'s `MENU_BEDS` carries the choice and the measurements
behind it; `docs/ROADMAP.md`, "THE FRONT DOOR PLAYTEST PASS", carries the
reasoning.

**The rule it adds:** *a negative finding is a finding.* "The original had
no X" is worth the same write-up as "the original had X", because without
it the next pass re-runs the same search and the one after that guesses.

## Tier 2 — the decompilation

| Source | Link |
|---|---|
| **MicroProse Shandalar source** — a decompilation of the original 1997 game, by Ben Prew | https://github.com/benprew/microprose-shandalar-source/ |
| **The write-up** describing that decompilation work | https://throwingbones.com/ben/blog/2026-08-shandalar-decomp/index.html |
| **`mp_pic_tools`** — tools for the original's `.PIC` art format | https://github.com/benprew/mp_pic_tools | **Surveyed 2026-09-03** (the open job in this file's own list, now closed): `spr2png.py::parse_spr` reads `.SPR` (per-frame 16-byte header, then one RLE run per line, palette index 0 transparent), `pic2png.py` + `pic_headers.py` read `.PIC` v3 (`M0`/`M1` palette blocks, `X0`/`X1` LZW+RLE image), `shared.py::tr2pal` reads `.tr` palettes. `tools/import_original.py` implements BOTH halves directly (2026-09-03) rather than depending on it, and its output is verified byte for byte against this reference. **Its sheet tiler drops frames**: `modulo = min(1240 // width, len(bitmaps))` with integer division, so any 137-wide sheet of 10-17 frames loses its tail — which is why s30's `16faces.spr.png` has nine of the fourteen portraits. |

**Status: FIRST SURVEY DONE 2026-09-02** (the decompilation only —
`mp_pic_tools` is still unread, see job 2). The survey was done to
establish the 1997 **Gauntlet** mode, and it answered it almost completely:
the run loop, the opponent shuffle, the round counter, the two Match Sizes
and the twenty-opponent cap are all readable in it. The write-up is
`docs/gauntlet-design.md` §0.4 and §2.3.

**What the decompilation is.** A **Ghidra headless decompilation of the
seven 1997 retail binaries** — `MAGIC.EXE` (Shandalar campaign + rules),
`DUEL.EXE` (the standalone duel program), `DECK.EXE`, `DECKDLL.DLL`,
`STATWIN.DLL`, `MAGSND.DLL`, `MAGVID.DLL` — 5,359 functions, with ~1,650
functions and 268 globals renamed, plus a per-binary `symbols.csv` naming
every string literal by its content and address.

**How to read it, which is not obvious.**

- **Control flow, string literals, dialog resource ids and control ids are
  machine-faithful.** They are the original read back, and they are what
  may be cited.
- **The function names and the doc comments are NOT.** They are inferred
  and several are simply wrong: the function that composes and shows the
  gauntlet's end-of-duel dialog is named `Ai_Duel_RenderBackdrop`, and the
  one that drives the whole gauntlet run is `Pic_Load_004420a1`. **Cite
  the entry-point ADDRESS, quote the code, ignore the name.**
- **Most globals are still `DAT_00xxxxxx`.** Any naming of them is the
  reader's inference and must say so.
- **The 1997 binaries hard-code their English strings.** The only data
  files `DUEL.EXE`'s string table names are `prompts.txt`, `hints.txt`,
  `master.csv`, `concise.csv`, `info.csv` and `tale.txt` — no
  `UIStrings.txt`, no `Text.res`. Those external tables belong to a later
  build. This does not weaken them: every `@GAUNTLET` and
  `@DIALOG_GAUNTLETENDDUEL` entry appears **verbatim as a literal** in the
  decompiled binary, which is the strongest corroboration a string table
  in this project has ever had.
- **Windows DIALOG templates carry their own default label text**, so a
  control the code only ever addresses by id still has words on it. Those
  templates are readable with `strings -el` over `Program/Magic.exe`, and
  cross-checking a template against a `@DIALOG_*` block is a cheap and
  very strong test of a string table's fidelity.

**Job 1 — how the decomp relates to `../shandalar-src` — ANSWERED.** They
are unrelated trees of the same game. `shandalar-src` is the **Manalink 3**
continuation and its `src/` is hand-written C against patched binaries; the
decompilation is the 1997 binaries themselves. **For any question about
1997 behaviour the decompilation outranks `shandalar-src/src/`.** The
gauntlet is the worked example: `shandalar-src/src/Magic-trace.c` gives it
only as a list of function names (`dlgproc_GauntletPage`, `save_gauntlet`,
`TENTATIVE_get_gauntlet_data_from_registry`) while the decompilation gives
the bodies. **The re-check of the duel findings that cite Manalink C
(`engine.c`, `functions.c`, `defs.h`, `dialog.c`, `windows.c`,
`deckdll.cpp`) is still open** — nothing in `docs/duel-todo.md` was
re-verified by that pass.

**AUDIO IS THE FIRST SLICE OF THAT RE-CHECK, done 2026-09-02**
(`docs/duel-todo.md` §3.8b). Three things came out of it worth recording
here, because they say what this source is and is not good for:

- **It confirmed a Manalink-derived claim from inside.** `MAGSND.DLL` is
  decompiled: a 272-entry table of one descriptor per loaded sound id,
  `IsSndLoaded` handing back that descriptor's slot, `GetLRUSnd` evicting
  within a caller-chosen range, `PlaySnd` re-triggering the buffer an id
  already owns. That is the 1997 mixer — polyphonic across sounds,
  monophonic per sound — and it matches exactly what
  `shandalar-src/src/functions/windows.c:1268-1317` implies from the
  caller's side.
- **It answered a question no Tier-1 or Tier-3 source could.** The coin
  flip is a pre-rendered AVI (`COINTOSS_Heads.AVI` / `COINTOSS_Tails.AVI`,
  embedded with `MCIWndCreateA` by `DUEL.EXE`'s dialog proc at entry
  `004492ad`), which is why no coin art exists anywhere to import. The
  music map came from the same place: `MAGIC.EXE` picks `LocMus0..19` by
  terrain and plays `Dueltune`/`Winduel`/`Loseduel` from one
  three-entry pointer table.
- **AND TIER 1 THEN CORROBORATED THAT COIN-FLIP FINDING, twice
  (2026-09-02), which is the pattern to imitate.** A decompilation answer
  is worth checking against the shipped binaries and the string tables,
  because when they agree the claim stops resting on inferred names.
  `Program/Magic.exe`'s own string table holds the dialog tag and the two
  movies in **three consecutive literals** — `DIALOG_COINFLIP`,
  `%s\COINTOSS_Tails.AVI`, `%s\COINTOSS_Heads.AVI` — and
  `@DIALOG_COINFLIP` (`UIStrings.txt:593-596`) is exactly two strings,
  `Coin flip results: Heads` / `Coin flip results: Tails`, one caption per
  movie. Same pass, same method: **`magvid.dll` names the codec itself.**
  It imports `AVIFileOpenA` / `AVIStreamRead` / `AVIStreamReadFormat` from
  `AVIFIL32.dll` and carries the fourcc literals `iv41` / `IV41` /
  `iv41j` hard-coded beside `LoadAVI` / `PlayAVI` / `StopAVI` /
  `UnloadAVI`. **The 1997 video codec is Indeo Video 4.1**, and all 69
  AVIs surviving in a Manalink install agree (`IV41`, 24-bit, 15fps).
  Godot plays Ogg Theora only, and no pure-Python Indeo decoder exists,
  so `tools/import_original.py` gained its first CONVERSION step for the
  coin movies (detected `ffmpeg` or `gst-launch-1.0`, frames tiled into a
  sprite sheet). **The two coin AVIs are in no reference tree** — checked
  2026-09-02, `../shandalar-src`'s 69 are all statistics-window
  animations plus the ending, and `../s30` has none — so that feature is
  available only to a player with a genuine 1997 install, and the game
  falls back to our own coin animation without it.
- **It has a real gap.** There is **no `WAV_*` enum in the
  decompilation** — every call site passes a bare integer, and the
  auto-generated function names around them are frequently wrong. So
  `shandalar-src/src/defs.h:2179` remains the only NAMED sound table
  anyone has, and the duel cue map still rests on Manalink C for the
  meaning of each id. Cite the decomp by ENTRY ADDRESS and quote the code;
  never trust a name.

**Job 2 — `mp_pic_tools` — ANSWERED 2026-09-03, and BOTH FORMATS ARE NOW
PORTED.** They are that decoder, and the importer now reads the player's
own raw files rather than a third party's conversion of them.
`tools/import_original.py` decodes `.SPR` natively (per-frame 16-byte
header, one RLE run per line, palette index 0 transparent) and takes its
palette from `Pedstls.pic`, which is what `MAGIC.EXE` loads immediately
before the portrait sheet. The first thing that came of it was five
portraits nobody had: the player pool is FOURTEEN faces, and the
community conversion everyone had been using drops frames 9-13 to an
integer-division bug in its tiler.

**`.PIC` followed the same day** (`decode_pic`), which closes the last
open item in this row. See "The `.PIC` format" below for what it is; what
it BOUGHT is the 55 enemy faces of `Faces/*.pic`, `Face.pic` and
`Advfac64.pic`, all decoded with the standard library and verified byte
for byte against `pic2png.py` on 63 files of the owner's install.

Ben Prew is also the author of **s30** and **mage-go** below, so all four
resources come from the same body of research.

## Tier 3 — reimplementations and continuations

| Source | Where | Used for |
|---|---|---|
| **s30** — the 30th-anniversary remake, in Go | `../s30`, `github.com/benprew/s30.git` | UI and adventure design, and the genuine 1997 text tables in `assets/text/`. Its own additions are tagged `[s30]` and never adopted silently. |
| **mage-go** — a Magic rules engine in Go | `../mage-go`, `github.com/benprew/mage-go.git` | The reference implementation for tricky cards and rules. Search its `cards/` by card name. |
| **Manalink 3 / Shandalar** | `../shandalar-src`, `github.com/ShandalarMagic/Shandalar.git` | The community continuation. Carries the 1997 `Program/` directory (Tier 1) **and** its own modernised art, text and code (Tier 3). Telling those apart is what the rules below are for. |
| **`../shandalar-src/Decks.zip`** and **`Program/decks/*.dck`** — the enemy deck files | `../shandalar-src/` | **Tier 3, established 2026-09-02** (`docs/decks-1997.md`). `Decks.zip`'s entries are dated **2016-02-15**: each `Decks/<id>.dck` is the 1997 enemy deck as a PREFIX (it equals s30's `main_cards` line for line, and mage-go's `rogue_dck/`) followed by a modern deck Manalink appended; `0150.dck` (Merfolk Shaman) is a full replacement with no 1997 prefix. **Take the prefix and the `.v<Colour>` sections; never the tail.** `Program/decks/*.dck` are the *Spells of the Ancients* enemy files carried in the 1997 `Program/` directory and agree with the wiki 54/55 — but `0150.DCK` is a Manalink replacement there too, and `0055.dck` (Warlock) lists `4 Fear` twice (64 cards; shipped as the file has it). No true 1997 enemy `.dck` exists anywhere locally; the 1997 lists survive INSIDE these files. |
| **`Program/Text.res`** | `../shandalar-src/Program/` | **Demoted from Tier 1 on 2026-09-02.** It looked like a larger copy of `UIStrings.txt` and greps cleanly (plain ASCII), which is why it got cited. It is Manalink 3's own table: `Momir Basic` (a **2006** format), `&Challenge Mode` where the 1997 gauntlet page has `&Ante`, `Highlander`, the network row `&Send Parameters`/`&Agree`/`&Disagree`, a tag absent from 1997 entirely (`@SHELLPAGE_MULTIDUEL`), and `199 unique / 499 total` cards where 1997 says `200 / 500`. **Use it to FIND a tag; quote the tag from `Program/UIStrings.txt`.** |

## Other sources

| Source | Notes |
|---|---|
| **Scryfall** | Card data — `tools/fetch_cards.py` populates `cards/data/*.json` (name, cost, type, oracle text, P/T, artist). Set folders use Scryfall codes (2ed/4ed/arn/atq/leg/drk/past/phpr). |
| **Comprehensive Rules** | Cited by number in comments for rules behaviour (CR 613 for layers, CR 603.3b for triggers). Modern CR is used to express rules the 1997 game implemented under Fifth Edition; where the two genuinely differ, the difference is a **fork** in `engine/rules_options.gd`, not a silent choice. |
| **The 1997 community FAQ** | `../s30/shandalar-faq.txt` — Dana Huyler, v1.2, 5 May 1997. Already cited in `docs/duel-todo.md` as **FAQ N.N**; registered here 2026-09-02. Contemporary, and it reproduces MicroProse's own patch-1.1 notes verbatim (its `Gauntlet` section is three of them). Secondary to the manual, but it is 1997 and it is specific. |
| **The 1998 *Advanced Strategy Guide*** | `../Magic the Gathering Advanced Strategy Guide 1998.pdf`. Secondary colour only — it is a card-strategy book about PAPER Magic. Cited as **guide p.N**. |
| **`docs/SHANDALAR_LORE.md`** | `../docs/` — systems tables for the adventure layer (M5). |
| **mtg.wiki — the MicroProse preconstructed decks** (Tier-web) | Registered 2026-09-02 for `docs/decks-1997.md`. Web sources rank BELOW every local tier: they fill gaps and cross-check, and a local 1997 file wins on disagreement (the disagreements are listed in that doc). **The authority for the GROUPING** — the partition into groups, their names and counts — is https://mtg.wiki/page/Magic:_The_Gathering_(MicroProse)_Preconstructed_Decks. Card lists cross-checked against, or (where nothing local exists) taken from: `https://mtg.wiki/page/Shandalar_Enemy_Decks_(Weak)` and its eleven siblings `(Aggro)`, `(Typical)`, `(Lesser)`, `(Intermediate)`, `(Genies)`, `(Greater)`, `(Strong)`, `(Dragons)`, `(Henchmen)`, `(Guildlords)`, `(Arzakon)` — the Original lists agree with the local files 55/55 on the maindeck; the *Duels of the Planeswalkers* variants (25 enemies) exist NOWHERE locally and are the wiki's; `https://mtg.wiki/page/Shandalar_Player_Decks_(Coyote_Tex)`, `(Kevin_Bane)`, `(Other)` — agree with mage-go's yaml 22/22. Screenshots of original `.DCK` files on `files.mtg.wiki` corroborate Sorceress, Cleric, Arzakon and seven play decks. A Reddit thread on the precon decks was a pointer only; nothing was taken from it. |
| **mtg.wiki — period community and tournament decks** (Tier-web) | The non-MicroProse decks of `decks/tournament/`, `decks/community/` and `decks/extended_community/` — NOT MicroProse's, and their files say so (`docs/decks-1997.md`, widened and split three ways 2026-09-02). Archetype pages: https://mtg.wiki/page/The_Deck (Weissman 1996 and his 2018 Old School version), https://mtg.wiki/page/Necropotence_deck, https://mtg.wiki/page/Sligh, https://mtg.wiki/page/Turbo_Stasis, https://mtg.wiki/page/Stompy. Event pages: https://mtg.wiki/page/Pro_Tour_Collector_Set (eight decks; mage-go's yaml transcription differs on two by a basic land — the wiki list ships, the diff is in the file), https://mtg.wiki/page/1994_World_Championships/Top_4_Decks, https://mtg.wiki/page/1995_World_Championships/Top_8_decks, https://mtg.wiki/page/1996_World_Championships/Standard_decks, https://mtg.wiki/page/1996_World_Championships/Other_decks, https://mtg.wiki/page/1997_World_Championships/Standard_decks, https://mtg.wiki/page/1997_World_Championships/Extended_decks, https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks, https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks, https://mtg.wiki/page/Tommi_Hovi. A list ships only as the page prints it, with the page's own caveats (UNCONFIRMED, RECONSTRUCTION, a sideboard-only or partial list is not shipped) in a `# caveat:` line. Fetched and found to carry NO list, so nothing shipped: Erhnamgeddon, Prison, Zoo, Land_Tax, Millstone, Counterpost. |
| **Stephen Menendian, *Old School Magic*** (Tier-web) | vintagemagic.com/blog, 2015–17, chapters 1–3, 5–9, 11–12 (URLs in `docs/decks-1997.md` and in each file). A modern historian's transcriptions of period lists (Weissman's The Deck 1994–97, Dolan, Chalice, Hyra, Wright, Robaina, Justice, Baxter, Comer…) and his own Old School 93/94 reference lists. Registered 2026-09-02. Where he and the wiki print the same period list (Dolan 1994, Lestrée 1994, Weissman 1996) they agree card for card, which is the cross-check. His reference lists are what `decks/extended_community/` is; his period transcriptions are in `decks/community/` and `decks/tournament/`, each dated as he dates it and flagged where he does not. |
| **Abe Sargent, *The Kitchen Table*** (Tier-web) | StarCityGames, 2009, #278 (green), #279 (red), #280 (black), #281 (blue), #289 (white), #296 (allied multicolour) — the Shandalar community's own re-tuned enemy decks. Each article prints the enemy's "Initial" list (the 1997 original — checked card for card against `decks/1997/originals/`, which is the cross-check), a "Modified" list for the game's own pool, and an "Updated" list with modern cards. The 39 Modified lists ship in `decks/community/`, every one proxy-free; the Initial lists are not shipped (they are the originals) and the Updated ones are not (modern cards). Registered 2026-09-02. |

---

## The rules for reading these sources

Every rule here was written after something went wrong. They are cheap to
follow and expensive to rediscover.

**`Program/UIStrings.txt` is latin-1, so `grep` prints NOTHING without
`-a`.** GNU grep decides the file is binary and silently reports nothing
rather than no-match. This cost this project a confidently wrong claim that
the tags were absent and that a different file was the real table. **Always
`grep -a` on the 1997 text tables.**

**Always the `Program/` copies of the string tables — but never
`Program/Text.res`, and prefer s30's `Uistrings.txt`.** The files at the
top of a Manalink install are Manalink 3 updates. `Program/Menus.txt` and
`Program/CueCards.txt` are updated too — for those two, the genuine 1997
copies live in `s30/assets/text/`.

Two corrections from 2026-09-02, both found while establishing the
Gauntlet, and both after a citation had already been shipped on the older
belief:

* **`Program/Text.res` is Manalink 3's table, not a 1997 superset of
  `UIStrings.txt`.** It is plain ASCII so it greps without `-a`, which is
  exactly why a pass reached for it. It carries `Momir Basic` (2006),
  `&Challenge Mode` **where the 1997 gauntlet page has `&Ante`**, a tag
  that does not exist in 1997 (`@SHELLPAGE_MULTIDUEL`) and `199/499` card
  limits where 1997 says `200/500`. **Find a tag in it; quote the tag from
  `Program/UIStrings.txt`.** Its `@SHELLPAGE_*` / `@SHELLSCREEN_*` blocks
  are the most rewritten and must never be quoted.
* **`Program/UIStrings.txt` itself carries a few Manalink edits**, all in
  the 1997 → modern direction: `Reach` for the 1997 keyword **`Web`**,
  `View exiled cards` for `View the out-of-play cards`, a shortened
  `-1/-1 counters`, `,name` for `,card type`, an expanded `@LANDWORDS`, an
  added `@GROUPMOVE`. **`s30/assets/text/Uistrings.txt` is the clean
  copy.** The two are line-for-line aligned **to line 1183** and
  `Program − 40` after it, so every citation this project has made so far
  reads the same in both — but a new one above line 1183 should be checked
  in s30's copy, and one below it must give both numbers.

**A Windows DIALOG template is a second witness, and a free one.**
`strings -el Program/Magic.exe` prints the dialog resources' own default
label text in layout order. Cross-checking a `@DIALOG_*` block against its
template catches exactly the failure the two rules above describe — it is
how `&Free play` was shown to be Manalink's (the 1997 `SINGLEDUELPAGE`
template has no such control, and its `Best of:` is an `msctls_updown32`
spinner, not one half of a radio pair).

**A `.bmp` inside a Manalink install is never a 1997 file.** The original
shipped `.PIC` and `.SPR`. A bitmap is a later addition — `WinBk_StartDuel.bmp`
is Manalink 3's own splash screen, not the original's.

**`Program/DBArt/*.pic` are PNGs wearing a `.pic` extension.** Check the
magic bytes, not the name.

**`Program/DuelArt/Face_*.pic` is not the duelist art.** All five files are
byte-identical to each other (one md5) — a flat grey gradient with noise,
Manalink's placeholder. The real 1997 portraits are `Life_<colour>pict.pic`.
The genuine 240×170 `Face_*` set (with a sixth, `Multi`) survives only
inside a `.7z` in a partial-clone git object store, is colour-reduced, and
is a **different asset** — the Versus screen's, not the life register's.
**That search is finished. Do not run it again.**

**Image and mask pairs have inconsistent mask polarity.** Do not assume one
convention across the asset set; check each pair.

**A screenshot is not a spec.** Where a screenshot and a shipped string
table disagree, the table wins. Where the printed manual and `Duel.hlp`
disagree, prefer the more specific one and record the conflict — the
five-versus-seven Combat Bar icons is the worked example.

**Read the reference before reimplementing.** The owner's standing rule,
verbatim: *"All of this is already implemented in Shandalar 30th
anniversary and you have the source! Why reinvent — only rewrite for
Godot!"* — *"this is true for everything!"*

---

## What ships, and what does not

**No copyrighted MicroProse or Wizards of the Coast material is in this
repository.** Not art, not the manual, not the string tables, not the
original's data files. What ships is our own code and prose, plus items
*derived* from those sources — a page citation, a measured pixel size, a
described behaviour.

The original's look is a runtime skin. A player who owns the 1997 game runs
`tools/import_original.py` against their own copy; it writes to a gitignored
directory that `game/skin.gd` picks up, and the 1997 look then appears
everywhere the clean fallback skin would otherwise show. Nothing in that
pipeline puts an original asset into version control, and the game is
complete and playable without it.

Card names and rules text are Wizards of the Coast's; card data comes from
Scryfall's public API and is used the way every fan tool uses it. Card
images are downloaded per-player, never redistributed.

### Our own assets — the short list, and where each came from

Almost nothing outside our code ships in the pack; `game/boot_splash.png`
was the whole list until 2026-09-04. These are the exceptions, and each one
gets a row here before it is committed.

| File | What it is | Source | Licence |
|---|---|---|---|
| `game/boot_splash.png` | the boot splash | ours | ours |
| `game/deck_builder/stone_grind.wav` | the Deck Builder's filter-button cue: 0.250 s, 22 050 Hz, mono, 16-bit PCM, 11 068 B | **supplied by the owner** as `freesound_community077381_scrapingstone83768.mp3` (47 040 B, 2.352 s) | **Pixabay Content License** as published; the underlying freesound.org entry could not be identified — see below |

**What is established about the grind, and what is not.** The owner's
playtest of 2026-09-04 asked for *"a quick stone grinding sound when
pressing the stone filter buttons, based on my sample"* and supplied the
mp3 above. Its name identifies it: it is **Pixabay sound-effect 83768**,
titled *"077381_Scraping Stone"*, uploaded by the Pixabay account
**"Freesound Community"**, and that page states *"Free for use under the
Pixabay Content License"* — which permits commercial use and requires no
attribution. That is the licence under which the file reached us, and it
is the licence this repository relies on.

**What could NOT be verified, and is therefore not claimed.** The `077381`
in the title is *not* a freesound.org sound id: `freesound.org/s/77381` is
an unrelated drum loop by `bigjoedrummer` (CC0). So the ORIGINAL uploader
on freesound.org, and whichever of CC0 / CC BY / CC BY-NC they chose there,
are unknown to us. This matters because the two licences are not the same
promise — freesound.org publishes under Creative Commons and Pixabay
re-publishes under its own Content Licence, a re-licensing that Freesound's
own forums dispute. Nothing here depends on the difference (the Pixabay
grant is sufficient on its own), but if the original is ever identified and
turns out to be CC BY, this project should carry that attribution instead.
Recorded rather than guessed, per the rule at the head of this file.

**What we did to it**, so the transform is on the record and repeatable
without ffmpeg (which this machine does not have):

1. `gst-launch-1.0 filesrc ! mpegaudioparse ! mpg123audiodec ! audioconvert
   ! audioresample ! audio/x-raw,format=S16LE,rate=22050,channels=1 !
   wavenc` — mp3 to 22 050 Hz mono 16-bit PCM, the rate every 1997 cue uses.
2. Trimmed to the 5 512 frames beginning at sample 1 040 (47.2 ms), which
   is just before the sample's own onset at 48.2 ms — so the attack is
   whole and the two seconds of drone after it are gone.
3. A 4 ms linear fade-in and a 70 ms raised-cosine fade-out, so the clip
   begins and ends on a zero sample and cannot click at either end.
4. Normalised x4.60, to a peak of 29 000 (-1.05 dBFS) from the excerpt's
   own 6 308.

`tests/ui/test_deck_sound.gd` reads the shipped file's RIFF header itself
and asserts all of that, so a re-trim cannot quietly change what ships.

---

## Where the citations live

This file is the register; the citations themselves are in the work.

- `docs/duel-todo.md` — every duel item, each traceable to a source, with a
  header explaining the citation formats and the `[1997]`/`[s30]`/`[QoL]`
  tags. Its §6 opens with the provenance rule about `Program/`.
- `docs/duel-screen-design.md` — the screen, pass by pass.
- `docs/glossary-1997.md` — the original's own vocabulary.
- `docs/simplified-cards.md` — every card that deviates from print, one row
  each. The promise that no shortcut is silent.
- `docs/gauntlet-design.md` — the 1997 Gauntlet mode, established from
  the string tables, the manual and the first survey of the Tier 2
  decompilation; opens with the provenance corrections above.
- `docs/decks-1997.md` — the ported 1997 decks: which file or page each
  of the 312 lists came from, and every disagreement between them. Each
  `.deck` file under `decks/1997/`, `decks/tournament/`, `decks/community/`
  and `decks/extended_community/` repeats its own sources in its header.
- `docs/ROADMAP.md` — engine-wide simplifications and milestones.
- `tools/import_original.py` — the MANIFEST maps skin keys to original
  filenames, and its comments carry the art-provenance findings, including
  the corrections recorded so they are not undone.
- Card files — a header doc comment with the card's name and exact oracle
  text, plus CR numbers at rules-relevant code.
