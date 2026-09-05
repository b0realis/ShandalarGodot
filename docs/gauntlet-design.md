# The Gauntlet — the 1997 mode we never built

**Status: BUILT (2026-09-02).** The design below was written first and
implemented from without re-deriving it; §9 at the foot records what
building PROVED, including the three places the design was wrong or
under-specified and the one decision it left to the owner (§5.1 — TAKEN,
as recommended). The mode ships as `GauntletState` +
`GauntletOptions` + `GauntletScreen`, reachable from the title screen.
The design text itself is left as it was written, because the reasoning is
the record.

This file is written the way `docs/duel-todo.md` §6.8a is written:
the sources first, in the order they answer the questions, each quoted
with its citation; then what that adds up to; then where our own code
stands; then the build, sliced; then what the sources cannot settle and
what I would choose instead, labelled `[QoL]` where the choice is ours.

Two things came out of this pass that are worth more than the mode:

1. **`Program/Text.res` is not a 1997 file.** `docs/duel-todo.md` §6's
   provenance box says it is "a SECOND, LARGER copy of the same table…
   a superset rather than a different file. Either may be cited."
   It is Manalink 3's table. §0 below has the evidence, and §0.3 lists the
   citations in shipped code that rest on it.
2. **The decompilation has now been surveyed** (first read, this pass) and
   it answers the gauntlet almost completely — the whole run loop, the
   opponent shuffle, the round counter, the two match sizes and the twenty
   opponent cap are all readable in it. `Provenance.md`'s Tier 2 section
   has been updated.

---

## 0. Provenance first — what may be cited, after this pass

### 0.1 `Program/Text.res` is Manalink 3's, not 1997's

The file greps cleanly (plain ASCII) where `Program/UIStrings.txt` needs
`grep -a`, which is exactly why a previous pass reached for it. But it
carries content that did not exist in 1997:

| `Program/Text.res` | Why it cannot be 1997 |
|---|---|
| `:2921` `Momir Basic` | a Magic format invented in **2006** |
| `:2845` `&Challenge Mode` | Manalink's own mode (`src/functions/challenge_mode.c`) — and it sits **in place of** the 1997 `&Ante` on the gauntlet page |
| `:2852` `@SHELLPAGE_MULTIDUEL` | a tag that **does not exist** in `Program/UIStrings.txt` at all |
| `:2859` `Highlander`, `:2873-2875` `&Send Parameters` / `&Agree` / `&Disagree` | the network-negotiation row of Manalink's multiplayer page |
| `:1382` `Decks are limited to 199 unique cards / 499 total cards` | the 1997 wording is **200 / 500** (`Program/UIStrings.txt:1372`, and the same in s30's copy) |

So `Program/Text.res` is a **later revision of the same table**, not a
superset of a 1997 one. The same `@TAG` can carry different words in the
two files, which is the failure mode that matters: a citation to
`Text.res:2861` for `&Ante` looks right and is reading a page Manalink
rewrote.

**Rule going forward: cite `Program/UIStrings.txt` (or s30's copy, below).
Use `Program/Text.res` only to find a tag, never to quote one** — and
never for a `@SHELLPAGE_*` or `@SHELLSCREEN_*` block, which is where
Manalink's changes are concentrated.

### 0.2 `Program/UIStrings.txt` itself has a few Manalink edits; `s30/assets/text/Uistrings.txt` is the clean copy

`Provenance.md` already records that the genuine 1997 `Menus.txt` and
`CueCards.txt` live in `s30/assets/text/`. **`Uistrings.txt` belongs on
that list too.** Diffing the two copies (`tr -d '\r'`, both latin-1) gives
seven differences and every one of them runs 1997 → modern in the
`Program/` direction:

| Line | `s30/assets/text/Uistrings.txt` (1997) | `Program/UIStrings.txt` (Manalink) |
|---|---|---|
| 222 | `Web` | `Reach` — the modern keyword; **the 1997 ability is Web** |
| 827 | `Mutation (-1/-1) counters: %d` | `-1/-1 counters: %d` |
| 904 | `View the out-of-play cards` | `View exiled cards` — "exile" is a **2009** term |
| 1160 | `,card type` | `,name` |
| 1185+ | `@LANDWORDS`, 4 entries per colour | 7 entries per colour (Manalink's text-substitution engine) |
| 1372 | `200 unique cards / 500 total cards` | *(same)* — the 199/499 change is in `Text.res` only |
| end | — | `@GROUPMOVE` added (a Manalink deck-builder feature) |

**The two files are line-for-line aligned up to line 1183**, so every
`UIStrings.txt:N` citation in this project below that line is correct in
both. After the `@LANDWORDS` insertions, `s30_line = Program_line − 40`
(`@GAUNTLET` is `1352` in `Program/`, `1312` in s30's).

Nothing in this document depends on a line above 1183 except `@GAUNTLET`
and `@GAUNTLETERRORS`, and both are given with both numbers.

### 0.3 What in shipped code rests on the Text.res citations

Not a lot, and nothing that is *wrong* — but three citations point at the
wrong file, and one **string** is Manalink's:

- `game/duel/match_state.gd` — `&Best of:` cited as `Program/Text.res:2862`
  and `&Free play` as `:2869`, both from `@SHELLPAGE_MULTIDUEL`. See §5,
  which is the whole of Job 2.
- `game/duel/duel_config.gd:22` — `&Ante` cited as `Program/Text.res:2861`.
  The claim is right and the 1997 citation is `Program/UIStrings.txt:48`
  (`@SHELLPAGE_SINGLEDUEL`), `:70` (`@SHELLPAGE_GAUNTLET`), `:90`
  (`@SHELLPAGE_SEALEDDECK`).
- `docs/duel-todo.md` §6.19 — same three, cited as
  `Program/Text.res:2861, 2911, 2925`, and it names `@SHELLPAGE_MULTIDUEL`
  (Manalink's) where the third 1997 page is `@SHELLPAGE_GAUNTLET`.
- `engine/deck_format.gd` — the five formats cited to
  `@SHELLPAGE_MULTIDUEL` / `Text.res:2854-2859`. The five names **are**
  1997: they are `@DECKTYPES` in `s30/assets/text/Mp_Uistrings.txt:12-17`,
  MicroProse's own multiplayer string file, spelled
  `Unrestricted / Wild / Restricted Type1 / Tournament Type1.5 /
  Highlander`. Only the citation needs moving.

### 0.4 The decompilation — first survey (Tier 2)

`https://github.com/benprew/microprose-shandalar-source/` was cloned and
read for the first time on 2026-09-02. What it is:

- **A Ghidra headless decompilation of the seven 1997 retail binaries** —
  `MAGIC.EXE` (Shandalar campaign + rules), `DUEL.EXE` (the standalone
  duel program), `DECK.EXE`, `DECKDLL.DLL`, `STATWIN.DLL`, `MAGSND.DLL`,
  `MAGVID.DLL` — 5,359 functions, with ~1,650 functions and 268 globals
  renamed.
- **Control flow, string literals, dialog resource ids and control ids are
  machine-faithful.** They are the binary read back, and they are what
  this document leans on.
- **The names and the doc comments are NOT.** They are inferred, and
  several are simply wrong: the function that composes and shows the
  gauntlet's end-of-duel dialog is named `Ai_Duel_RenderBackdrop`, and the
  one that drives the whole gauntlet is named `Pic_Load_004420a1`. **Cite
  addresses, quote code, ignore the names.**
- Most globals are still `DAT_00xxxxxx`. The mapping table in §2.3 is
  mine, derived from use; it is inference, not a symbol the repo ships.

**How it relates to `../shandalar-src`** (the first of the two jobs
`Provenance.md` was holding for this survey): they are unrelated trees of
the same game. `shandalar-src` is the **Manalink 3** continuation and its
`src/` is hand-written C against the patched binaries. The decompilation
is the 1997 binaries themselves. **For any question about 1997 behaviour
the decompilation outranks `shandalar-src/src/`** — this pass is the
worked example: `shandalar-src/src/Magic-trace.c` gives the gauntlet only
as a list of function names (`dlgproc_GauntletPage`, `save_gauntlet`,
`TENTATIVE_get_gauntlet_data_from_registry`), while the decompilation
gives the bodies.

One caveat found immediately: **the decompiled 1997 `DUEL.EXE` hard-codes
its English strings.** The only data files its string table names are
`prompts.txt`, `hints.txt`, `master.csv`, `concise.csv`, `info.csv` and
`tale.txt` — no `UIStrings.txt`, no `Text.res`. Those external tables
belong to a later build (the expansions' unified executable). This does
not weaken them: every `@GAUNTLET` and `@DIALOG_GAUNTLETENDDUEL` entry
below appears **verbatim as a literal** in the decompiled binary, which is
the strongest corroboration this project has ever had for a string table.

---

## 1. The 1997 sources, in the order they answer the questions

### 1.1 There is a Gauntlet, and here is what it is for

`@SHELLSCREEN_DUEL` (`Program/UIStrings.txt:5-11`) — the shell's Duel
screen, four entries with their own one-line descriptions:

> `Duel`
> `4Duel &Opponent:Duel your registered opponent.`
> `1Solo &Duel:Single game or match of Magic.`
> **`2&Gauntlet:Defeat as many opponents in a row as possible.`**
> `3&Sealed Deck:Compete in the most popular form of Magic Tournament.`

That sentence is the specification of the mode in nine words: **a run of
opponents, one after another, that ends when you lose.** The leading digit
is the entry's position; Manalink's `defs.h:2033-2037` names the same
three as `GAMETYPE_SOLO_DUEL = 1`, `GAMETYPE_GAUNTLET = 2`,
`GAMETYPE_SEALED_DECK = 3`, which is that numbering.

### 1.2 It was configured on TWO different screens, and they are not the same feature

**(a) The shell's Gauntlet page** — `@SHELLPAGE_GAUNTLET`
(`Program/UIStrings.txt:58-75`), sixteen entries:

> `Player:`
> `&Your deck:` / `<random deck>`
> `Gauntlet difficulty: %3d (%s)` / `very easy` / `easy` / `normal` / `hard` / `very hard`
> `&Num opponents:`
> `&Ante`
> `&Best of:`
> `Side&board between duels`
> `Duel &Options...`
> `&Run the gauntlet`
> `&Load gauntlet...`

The dialog template confirms the control types. (`Program/Magic.exe` is
Manalink's binary — it contains `Momir Vig` — but it kept the 1997
`GAUNTLETPAGE`, `SINGLEDUELPAGE` and `SEALEDDECKPAGE` resources and added
`MULTIDUELPAGE` beside them; each of the three old templates matches its
1997 `@SHELLPAGE_*` block entry for entry, which is what makes it usable.
`strings -el` reads them.) `&Ante` is a checkbox, and **both `Best of:`
and `Num opponents:` are `msctls_updown32` spinners** — numeric edit boxes
with up/down arrows, not radio pairs.
(The template also shows Manalink's rewrite: `Text.res` puts
`&Challenge Mode` where the template still says `&Ante`.)

`Gauntlet difficulty: %3d (%s)` is a **computed readout, not a setting** —
a number with a name beside it, from five bands. The manual says how one
of the inputs feeds it (p.138): *"ANTE is a checkbox that determines
whether you play each duel for an ante card. **Playing for ante adds 1 to
the Difficulty.**"*

**(b) The duel program's own Gauntlet Startup screen** —
`@DIALOG_GAUNTLETSTARTUP` (`Program/UIStrings.txt:634-650`), fifteen
entries:

> `Game` / `&Gauntlet` / `&Single Duel`
> `DIFFICULTY:`
> `Gauntlet &Options...` / `&Duel Options...`
> `O&pponent's Deck` / `Random deck` / `Pick a deck`
> `&Your deck` / `Random deck` / `Pick a deck`
> `&Create Deck...`
> `&Load saved game...`
> `E&xit`

and its options dialog, `@DIALOG_GAUNTLETOPTIONS`
(`Program/UIStrings.txt:620-632`), eleven:

> `Gauntlet Options`
> `Difficulty`
> `Match Size` / `Best of &Three` / `Best of &One`
> `A&nte`
> `Enemy Level` / `&Apprentice` / `&Magician` / `&Sorcerer` / `&Wizard`

The manual (p.156) describes that Match Size pair in words: *"Match Size
is a choice between two options. You can either play every match as a two
out of three contest or decide each match on the strength of a single
duel."*

**This is the screen the decompilation implements**, and it is the one
this design follows: it is the only gauntlet configuration for which we
have both the strings and the code.

### 1.3 What a gauntlet run consists of

`@GAUNTLET` (`Program/UIStrings.txt:1352-1363` = `s30/…/Uistrings.txt:1312-1323`),
ten strings, and **every one of them is a hard-coded literal in the
decompiled 1997 `DUEL.EXE`** (0x505a04, 0x505a1c, 0x505a28, 0x505a54,
0x505a78, 0x505a9c, 0x505ab8, 0x505ae0, 0x505af8, 0x505b10):

> 1 `\n Congratulations!\n\n`
> 2 `\n Too bad\n\n`
> 3 `\n Oh well... \nThe duel ended in a tie\n\n`
> 4 `You won the match.\n\n`
> 5 `\n\n Your next duel is against %s.\n`
> 6 ` Do you wish to continue?`
> 7 ` You've successfully run the gauntlet!\n`
> 8 ` You've won the duel!\n`
> 9 ` You lost the game.\n`
> 10 `\n\n The match continues...`

The decompiled driver (`DUEL.EXE`, entry point **0x4420a1**;
`duel/duel_unified.c` around line 66940 in the repo as cloned) assembles
one message out of those ten, in this order and no other:

```
result line   : #1 won / #2 lost / #3 tied            (one, always)
then exactly one of:
  #10  "The match continues..."        — nobody has taken the match yet
  #9   "You lost the game."            — the OPPONENT reached wins-needed
  #4 + #5 + #6                         — YOU took the match, and there is
       "You won the match." + "Your next duel is against <deck>." +
       "Do you wish to continue?"          another opponent after this one
  #7   "You've successfully run the gauntlet!"  — you took the LAST match
  #8   "You've won the duel!"          — single-duel mode, not gauntlet
```

So the unit of progress is a **match**, not a duel. `That was round %d`
(§1.5) counts matches. Entry 8 is the branch that proves the same driver
serves both `&Gauntlet` and `&Single Duel`.

### 1.4 Opponents: how many, which, and in what order

All of this is the decompilation, corroborated by a 1997 patch note.

**How many.** `UI_DialogProc_0049c2d0` (the Gauntlet Startup screen, dialog
resource `0xe7`) counts the deck files it can offer and then:

```c
DAT_005f6288 = <number of .dck files found>;        /* fills both combos */
if (DAT_005f6288 == -1) { EndDialog(hwnd,-1); }     /* @GAUNTLETERRORS 12 */
DAT_005f649c = DAT_005f6288;
if (0x13 < DAT_005f6288) { DAT_005f649c = 0x14; }   /* cap at 20 */
```

**The gauntlet is `min(number of decks on disk, 20)` opponents long**, and
the cap is real: the shuffle buffer is `int aiStack_54[20]`. This screen
has no `Num opponents` spinner — that is the shell page's (§1.2a), and the
shell binary is not in the decompilation.

**Which, and in what order.** `FUN_0049e6f9` (**0x49e6f9**), called
straight after the count:

```c
for (i = 0; i < DAT_005f649c; i++) aiStack_54[i] = i;
for (i = 0; i < DAT_005f649c * 10; i++) {          /* 10n random swaps */
    r = _rand();
    swap(aiStack_54[i % n], aiStack_54[r % n]);
}
for (i = 0; i < n; i++) copy deckname[aiStack_54[i]] -> gauntlet_list[i];
```

Two facts fall out. **The order is shuffled**, and the shuffle draws its
indices from `[0, n)` — so when there are more than twenty decks on disk,
the gauntlet is the **first twenty in enumeration order**, shuffled among
themselves, and deck 21 onward is never met.

**Where the run starts in that order** — `FUN_0049e921` (**0x49e921**),
the `Random deck` branch for the opponent:

```c
if (gauntlet) { DAT_005f6498 = _rand() % DAT_005f649c; }   /* start index */
```

and the driver picks each round's opponent as

```c
local_5c = (DAT_005f6498 + DAT_005f6cb0) % DAT_005f649c;   /* start + round */
_sprintf(path, "%s\\%s.dck", <deck dir>, gauntlet_list[local_5c]);
```

so the run walks the shuffled list from a random offset and **wraps**. The
same dialog proc **disables `Pick a deck` and the opponent combo whenever
`&Gauntlet` is selected** (control ids `0x468` and `0x463`): in a gauntlet
you do not choose your opponents.

The 1997 FAQ (Dana Huyler, v1.2, 5 May 1997, `s30/shandalar-faq.txt:458-465`),
quoting MicroProse's own patch notes under the heading `Gauntlet`:

> `*  The Next Opponent screen displays the correct name for the next opponent.`
> `*  The typo in the Next Draw screen has been fixed.`
> **`*  The random selection of opponents in the Gauntlet is now fixed.`**

— which is the same three things from the other side: a next-opponent
announcement that names a deck, and a random selection that shipped
broken.

`@DIALOG_STARTEXP1MATCH_GAUNTLET` (`Program/UIStrings.txt:149-153`) is the
announcement itself, and it knows the run's length:

> `Your first opponent in the gauntlet:`
> `You now meet opponent %1!d! (of %2!d!) in the gauntlet:`
> `Your final opponent in the gauntlet:`

### 1.5 What happens between duels, and between matches

**Between the duels of one match** — nothing new: it is the ordinary match
between-duels window this project already builds
(`@DIALOG_ENDEXP1DUEL_BUTTONS`, `Program/UIStrings.txt:564-571`), whose
six entries are

> `Side&board...` / `Side&board...` / `&Edit deck...` /
> **`&Save match` / `&Save gauntlet` / `&Save tournament`**

— three save verbs, one per shell mode, on one window. `Side&board between
duels` is a gauntlet parameter as much as a solo-duel one
(`@SHELLPAGE_GAUNTLET` entry 13).

**Between matches** — `@DIALOG_GAUNTLETENDDUEL`
(`Program/UIStrings.txt:520-525`), four entries:

> `That was round %d`
> `Your record is %d/%d/%d`
> `&Next round`
> `&Quit Gauntlet`

The decompilation shows exactly how those are used. The dialog is resource
`0xf6`; its template (readable in `Program/Magic.exe`) carries three
readouts labelled `Wins`, `Losses`, `Round` and two buttons whose default
text is `&Continue` / `E&xit`. The message is composed by one `sprintf`
with the format `"%s That was round %d Your record %d/%d/%d"` (literal at
`MAGIC.EXE` 0x52d158 / `DUEL.EXE` 0x4f7c78), and its five arguments are,
in order: **the `@GAUNTLET` message from §1.3, the round number, and the
session totals — wins, losses, ties.** The buttons are then relabelled:

```c
if (gauntlet_flag == 0) {                    /* not a gauntlet */
    hide(0x493);  SetDlgItemText(0x494, <OK>);  focus = 0x494;
} else {
    SetDlgItemText(0x493, "&Next Round");
    SetDlgItemText(0x494, "&Quit Gauntlet");   focus = 0x493;
}
```

and if the run is over at all, **both buttons are hidden** — there is no
`Next Round` to offer. `&Next round` returns 4 from the dialog, `&Quit
Gauntlet` and the window's close box both return 0.

**The record is `wins/losses/ties` across the whole run**, not the current
match: they are three separate counters from the two the match keeps
(0x5f76c0 / 0x5f6494 / 0x5f67fc against 0x5f6c58 / 0x5f67e8), and the
match pair is zeroed every time a match ends while the session triple is
not.

**Your deck between matches.** The Deck Builder has a gauntlet mode of its
own: `@MAINMENU_GAUNTLET` (`s30/assets/text/Menus.txt:230-239`) and
`@DECKSURFACE_GAUNTLET` (`:182-192`) are the standalone builder's menus
**minus `M&inimize`** — every other entry identical. Manalink's
`src/deck/deckdll.cpp:29,4773,6030` shows the flag that selects them
(`DBFLAGS_GAUNTLET = 8`) and that it travels with
`DBFLAGS_NOCARDCOUNTCHECK`. The startup screen reaches the builder through
`&Create Deck...` (control `0x44e`), which calls
`DeckBuilderMain(hwnd, 0x18, 1)` and then **re-enumerates the decks and
re-shuffles the gauntlet**.

### 1.6 What is won and lost

**Ante**, and nothing else. `&Ante` is on the shell's gauntlet page
(`Program/UIStrings.txt:70`) and `A&nte` in the options dialog (`:627`);
the manual (p.138) makes it a difficulty input as well as a stake:
*"Playing for ante adds 1 to the Difficulty."*

There is **no card collection, no purse, no progression** anywhere in the
gauntlet's strings or in the decompiled driver. Whatever the ante rules
do, the mode's own reward is the sentence `You've successfully run the
gauntlet!` — the run is the reward. (Contrast Shandalar, where the ante
economy is the whole game.)

### 1.7 How a run ends — all four ways

From the driver at 0x4420a1, exhaustively:

1. **You lose a match** → `You lost the game.`, the continue buttons are
   hidden, the round counter is reset to 1, and the next thing the player
   sees is the **Gauntlet Startup screen again** (the driver's state
   machine falls back to case 0, which calls `FUN_0049c24f`, dialog
   `0xe7`). A gauntlet cannot be resumed after a loss.
2. **You win the last match** → `You've successfully run the gauntlet!`,
   same exit.
3. **You press `&Quit Gauntlet`** → dialog returns 0, same exit.
4. **A deck fails to load** → a `@GAUNTLETERRORS` message box
   (`Program/UIStrings.txt:1365-1378` = s30 `:1325-1338`) and back to the
   startup screen. The **opponent's** deck is validated every round, with
   its own four messages (`Opponent's deck %s is invalid.` / `Wrong
   version number.` / `Decks must have a minimum of 40 cards.` /
   `Decks are limited to 200 unique cards / 500 total cards.`). **Your**
   deck has the same three tests under `Player's deck %s is invalid.`
   (entries 2, 4, 5) and the nameless entry 1, `Your selected deck is not
   a legal deck. Please select a new deck.` — checked once, on `&Run the
   gauntlet`, and a refusal puts the startup screen back (§11).

Case 0 of that state machine is also where the run is *initialised*, and
it is worth quoting for two numbers it settles:

```c
DAT_00681eac = 0x14;  g_DuelPlayerLifeTotals = 0x14;   /* 20 life each */
DAT_005f67e8 = 0; DAT_005f6c58 = 0;                    /* match record */
DAT_005f6cb0 = 1;                                      /* round = 1 */
DAT_005f6498 = 0;                                      /* start index */
```

Starting life is **20** — the manual says the same of the standalone Duel
(p.157, *"both players… the traditional 20 life"*), against Shandalar's
variable life.

### 1.8 Saving

`@SAVEGAMEFILETYPE` (`Program/UIStrings.txt:165-170`):

> `MTG Gauntlet Save Game` / `MtG Saved Match` / `MtG Saved Gauntlet` / `MtG Saved Tournament`

`&Load gauntlet...` is on the shell page, `&Load saved game...` on the
startup screen, `&Save gauntlet` on the between-duels window. A gauntlet
was a savable, resumable object. The decompiled load path is interesting
for what it *drops*: on a successful load the startup screen sets the game
type back to **single duel** and wins-needed to **1** before starting
(`DAT_005f64b0 = 1; DAT_005f628c = 1;`), which is either a 1997 defect or
a save format that only ever held a duel. **I could not settle which, and
it does not matter for us** — see §6, where saving is out of scope.

### 1.9 What `Duel.hlp` says about the gauntlet: nothing

Checked exhaustively. `Duel.hlp` (11 Nov 1997) has five top-level
sections — `About Cards`, `Card Listing`, `Parts of the Dueling Screen`,
`Phases`, `Terminology` (`Duel.cnt:2,47,686,702,710`) — and its only
"gauntlet" is the card *Gauntlet of Might*. **The shipped help file
documents the dueling table and the cards, not the shell.** The gauntlet's
prose authority is the printed manual (p.138 for the shell page, p.156 for
Match Size) and nothing else.

---

## 2. What that adds up to

### 2.1 The mode, in one paragraph

A **gauntlet** is a run of **N matches** against **N different opponent
decks**, drawn from the deck folder, shuffled, entered at a random point
and walked in order with wraparound. Each opponent is a **match** of the
chosen Match Size — best of three (two wins) or best of one. You keep your
deck between matches and may edit it; you may sideboard between the duels
of a match if that parameter is on; each duel may be played for ante. A
running **wins/losses/ties** record and a **round number** are shown after
every duel. **Losing a match ends the run**; winning the last one ends it
with `You've successfully run the gauntlet!`. The run can be quit at any
between-duels window, and it can be saved.

### 2.2 The loop, as a state machine

```
     ┌──────────────────────────── Gauntlet Startup screen ──────────────┐
     │  Game: [Gauntlet | Single Duel]      DIFFICULTY: n                │
     │  Your deck: (Random | Pick)   Opponent: (Random | Pick — GREYED   │
     │                                         while Gauntlet is chosen) │
     │  [Gauntlet Options...] [Duel Options...] [Create Deck...]         │
     │  [Load saved game...]  [OK]  [Exit]                               │
     └───────────────┬───────────────────────────────────────────────────┘
                     │  OK          life := 20, round := 1,
                     │              order := shuffle(decks)[0..min(n,20)),
                     ▼              start := rand() % len(order)
        ┌────────► play one DUEL of the current match ◄─────────┐
        │                     │                                  │
        │                     ▼                                  │
        │        record the duel (won / lost / tied)             │
        │        session totals += 1 ; match wins += 1           │
        │                     │                                  │
        │                     ▼                                  │
        │   ┌──── neither side has wins_needed? ────► "The match continues..."
        │   │                                          [Next round] ──┘
        │   │
        │   ├──── opponent reached it ────► "You lost the game."   → RUN OVER
        │   │
        │   └──── you reached it ─┬── more opponents?  "You won the match."
        │                         │                    "Your next duel is
        │                         │                     against <deck>."
        │                         │                    "Do you wish to
        │                         │                     continue?"
        │                         │                    round += 1  ──────┘
        │                         │
        │                         └── that was the last: 
        │                             "You've successfully run the gauntlet!"
        │                                                        → RUN OVER
        └── every one of those shows ONE window:
               <message>  "That was round N"  "Your record is W/L/T"
               [Next round]  [Quit Gauntlet]      (both hidden if RUN OVER)
```

### 2.3 The globals, named (my mapping, from use — not shipped symbols)

| Address (`DUEL.EXE`) | What it is |
|---|---|
| `0x5f64b0` | game type: **0 = gauntlet**, 1 = single duel |
| `0x5f628c` | **wins needed for a match**: 2 (Best of Three) or 1 (Best of One) |
| `0x5f6288` | number of deck files found |
| `0x5f649c` | **gauntlet length** = `min(0x5f6288, 20)` |
| `0x5f6cc0` | the shuffled opponent list, 0x80 bytes per deck name |
| `0x5f2fb0` | the master deck-name list the shuffle draws from |
| `0x5f6498` | start offset into the shuffled list |
| `0x5f6cb0` | **current round**, 1-based |
| `0x5f6c58` / `0x5f67e8` | duel wins in the CURRENT match: you / opponent |
| `0x5f76c0` / `0x5f6494` / `0x5f67fc` | SESSION wins / losses / ties |
| `0x5f77ec` | show `Next Round` / `Quit Gauntlet` rather than a lone OK |
| `0x5f2f50` | Enemy Level, 0..3 = Apprentice / Magician / Sorcerer / Wizard |
| `0x5f64a4` | the `Ante` checkbox |
| `0x5f6c54`, `0x5f76c4` | opponent-deck / your-deck source (random vs picked) |

Dialog resources: **0xe7** startup, **0xe8** Gauntlet Options, **0xf6**
end-of-duel. Control ids: `0x453/0x454` Gauntlet/Single Duel,
`0x456/0x457` Best of Three/One, `0x45a-0x45d` the four Enemy Levels,
`0x46a` Ante, `0x455` the DIFFICULTY readout, `0x467/0x468` opponent deck
random/pick, `0x465/0x466` your deck random/pick, `0x469` Gauntlet
Options…, `0x47f` Duel Options…, `0x44e` Create Deck…, `0x49c` Load saved
game…, `0x493` Next round, `0x494` Quit Gauntlet.

One curiosity, recorded so nobody re-derives it: the Gauntlet Options
dialog proc (**0x49eaa0**) also initialises three radio pairs
(`0x458/0x459`, `0x45e/0x45f`, `0x460/0x461`) that the dialog **template
has no labels for**, and `@DIALOG_GAUNTLETOPTIONS` has no strings for. One
of them keys off the value `0x3c` (60) — plausibly a minimum-deck-size
pair, since `&40 cards` / `&60 cards` is a real parameter on the other two
shell pages. They are dead controls in this build. **Do not build them.**

---

## 3. Where our own code stands (verified 2026-09-02)

The honest headline: **we already have the inner two thirds of this mode.**

- **`MatchState` (`game/duel/match_state.gd`, 140 lines) is the match**,
  and it is complete for the gauntlet's needs: `best_of`, `wins[2]`,
  `draws`, `wins_needed()`, `record()`, `is_over()`, `winner()`,
  `progress_line()`, `verdict()`, `duel_heading()`. `wins_needed()` is
  already `best_of / 2 + 1`, so `best_of = 1` gives 1 and `best_of = 3`
  gives 2 — the original's two Match Sizes, with no change.
- **`MatchScreen` (`game/duel/match_screen.gd`, 332 lines) is the match
  LOOP** — it owns a sequence of `DuelScreen`s, records each result, draws
  each duel's seed from the match's one seed so a whole match replays,
  puts up the between-duels window, and runs the `Side&board...` step. Its
  headless branch plays a match straight through with no windows.
- **`DuelConfig`** already carries `decks`, `sideboards`, `player_names`,
  `lives`, `pilots`, `panel_colors`, `pace`, `ante`, `best_of`,
  `sideboard_between_duels`, `deck_format`, `rng_seed`.
- **`AiProfile` already has the four Enemy Levels by name** —
  `AiProfile.apprentice() / .magician() / .sorcerer() / .wizard()`
  (`engine/ai/ai_profile.gd:80-99`), and the battle-setup screen already
  offers them per seat.
- **Decks on disk already exist** (`decks/*.deck`, five of them) with a
  loader, a `DeckList` parser that round-trips `SB:` sideboards, and
  `DeckFormat` legality.
- **`--gauntlet` in the Deck Lab is a different thing and must not be
  confused with this.** `tools/simulate.gd` uses the word for "deck A vs
  each of a pool, N games per matchup" — a round-robin measurement, not a
  survival run. It keeps its name; this mode is the game one.

**What is genuinely missing is the OUTER loop and its screen**: a run of
matches with a round counter and a session record, an opponent order, and
the two windows (`Gauntlet Options`, and the round window with `Next
round` / `Quit Gauntlet`). That is the whole of the work.

---

## 4. The design, in the order it should be built

Four slices. Slices 1-3 are the mode; slice 4 is the polish that makes it
feel like 1997 rather than like a loop.

### Slice 1 — `GauntletState`, pure, no screen (engine-adjacent, `game/duel/`)

New `game/duel/gauntlet_state.gd`, a `RefCounted` in the same key as
`MatchState` — no Node, testable headless, one job.

```gdscript
class_name GauntletState
const MAX_OPPONENTS := 20          # aiStack_54[20], 0x49e6f9
var order: Array[String] = []      # deck paths, already shuffled
var start := 0                     # 0x5f6498
var round := 1                     # 0x5f6cb0, 1-based
var wins := 0                      # 0x5f76c0   session totals, not the
var losses := 0                    # 0x5f6494   current match's
var ties := 0                      # 0x5f67fc
var over := false
func length() -> int                       # order.size()
func opponent_index() -> int               # (start + round) % length()
func opponent() -> String
func is_final_round() -> bool              # round == length()
func record_match(won: bool) -> void       # advances or ends the run
func record_duel(result: int) -> void      # session totals only
static func shuffle(decks: Array[String], rng: RandomNumberGenerator,
                    limit := MAX_OPPONENTS) -> Array[String]
```

`shuffle` reproduces 0x49e6f9 **in effect, not instruction for
instruction**: take the first `min(len, 20)`, permute them, and note in
the doc comment that the original's 10n-swap loop is a weaker shuffle than
a Fisher-Yates and that using a proper one is `[QoL]` with no visible
difference. All randomness through `MtgGame.rng`'s type
(`RandomNumberGenerator`, seeded), never `randi()` — rule 7.

The strings live here as constants, verbatim from `@GAUNTLET` and
`@DIALOG_GAUNTLETENDDUEL`, with the `\n` runs dropped the way `MatchState`
already drops them (the caller lays the window out):

```gdscript
const WON_MATCH  := "You won the match."
const CONTINUES  := "The match continues..."
const LOST_RUN   := "You lost the game."
const RAN_IT     := "You've successfully run the gauntlet!"
const NEXT_IS    := "Your next duel is against %s."
const CONTINUE_Q := "Do you wish to continue?"
const ROUND_LINE := "That was round %d"
const RECORD     := "Your record is %d/%d/%d"
const NEXT_ROUND := "Next round"
const QUIT       := "Quit Gauntlet"
```

**Tests** (`tests/ui/test_gauntlet_state.gd`): the cap at 20; the wrap in
`opponent_index`; that a lost match sets `over`; that the last round's win
sets `over` with `RAN_IT`; that the session record is not the match
record; determinism of `shuffle` under a fixed seed.

*Nothing on screen changes in this slice, which is the point of it.*

### Slice 2 — `GauntletScreen`, the outer loop

New `game/duel/gauntlet_screen.gd` + `.tscn`, built as a **sibling of
`MatchScreen` that owns `MatchScreen`s**, exactly as `MatchScreen` owns
`DuelScreen`s. That nesting is the design: a gauntlet is a sequence of
matches, a match is a sequence of duels, and each layer knows only the one
below it.

- `_ready()` builds the run from a `GauntletConfig` (slice 3), instantiates
  one `MatchScreen` per round, and connects a new
  `signal MatchScreen.match_finished(winner_id: int)`.
- **`MatchScreen` needs exactly one change**: it currently calls
  `_leave()` → `change_scene_to_file("res://game/main.tscn")` when a match
  ends. It must emit `match_finished` instead when it has a listener, and
  keep the scene change when it does not — the same shape
  `DuelScreen.duel_finished` already has. Everything else in it works
  unchanged, sideboard step included.
- Each round's `DuelConfig` is the run's, with `decks[opponent_seat]`
  loaded from `GauntletState.opponent()` and the opponent's name set to
  the deck's name — which is what `Your next duel is against %s` prints.
- **One seed for the run**, split per match the way `MatchScreen` already
  splits per duel (`_seeder.randi() | 1`). A gauntlet then replays whole,
  and round 4 of a run is reproducible only as round 4 of that run.

**The round window** is the between-matches window, and it is a second
`OriginalDialog` at `MatchScreen.WINDOW_Z + 1`:

```
                   Gauntlet
  <You won the match. | The match continues... |
   You lost the game. | You've successfully run the gauntlet!>
  <Your next duel is against Big Green.>          (only when there is one)
  <Do you wish to continue?>                      (only when there is one)
  That was round 3
  Your record is 5/2/0
  [ Next round ]  [ Quit Gauntlet ]     ← both HIDDEN when the run is over,
                                          and then a single [ OK ]
```

Two rules from §1.5 that are easy to get wrong and are worth a test each:
**the record is the session's, not the match's**, and **when the run is
over the two buttons are not disabled, they are absent** (the original
hides them and shows the lone OK button; §6.1's "grey what you cannot
offer" is about menu entries, not about a dead-end dialog).

**Headless behaviour must match `MatchScreen`'s**: no windows, play
straight through, so a whole gauntlet can be simulated in a test in
milliseconds.

**Tests** (`tests/ui/test_gauntlet_screen.gd`): a two-deck run headless
plays two matches; a loss in round 1 stops the run; the round window's
lines for each of the four branches; `match_finished` fires once per
match; two runs from the same seed produce the same opponent order and the
same duel results.

### Slice 3 — the Gauntlet Options window and the way in

New `game/duel/gauntlet_options.gd`, in the shape of
`game/duel/duel_options.gd` (a `RefCounted` holding the table, the
`Settings` keys and a `static func window() -> OriginalDialog`), carrying
`@DIALOG_GAUNTLETOPTIONS` entry for entry:

| Entry | Control | Value |
|---|---|---|
| `Gauntlet Options` | title | — |
| `Difficulty` | **read-only readout** | see §5.2 |
| `Match Size` | radio pair | `Best of Three` → `best_of = 3`, `Best of One` → `best_of = 1` |
| `Ante` | checkbox | `DuelConfig.ante` |
| `Enemy Level` | radio, four | `AiProfile.apprentice/magician/sorcerer/wizard` |

plus `Side&board between duels` and `Num opponents:`, which belong to the
**shell page** rather than this dialog (§1.2a) and which I would put here
anyway — see §5.4.

**The way in.** The 1997 route is a shell we do not have. Ours:
`game/main.gd` grows a **`Gauntlet`** button between `Magic Battle` and
`Deck Builder`, carrying `@SHELLSCREEN_DUEL`'s own description as its
tooltip — *"Defeat as many opponents in a row as possible."* — exactly as
`Deck Builder` already carries *"Build or Modify decks."* from
`@SHELLSCREEN_TOOLS`. It opens a setup screen that is the battle-setup
screen with the opponent column replaced by the gauntlet parameters.

**Reuse, do not fork, `setup_screen.gd`.** It already owns deck loading,
format legality, proxy refusal, ante, best-of and sideboard. The gauntlet
setup is that screen with three differences: no opponent deck picker (the
original greys it), a `Num opponents` spinner, and `Run the gauntlet`
instead of `Go`. Whether that is a mode flag on `SetupScreen` or a second
scene sharing a helper is an implementation call for the pass that builds
it; a flag is smaller and the screen is already 706 lines, which argues
for extracting the deck-picker column first.

### Slice 4 — the 1997 finish

- **The opponent announcement.** `@DIALOG_STARTEXP1MATCH_GAUNTLET`'s three
  lines (`Your first opponent in the gauntlet:` / `You now meet opponent
  %d (of %d) in the gauntlet:` / `Your final opponent in the gauntlet:`)
  on the pre-match window, over the opponent's name — the first, middle
  and last variants, which is a nice piece of 1997 texture for three
  strings.
- **The four difficulty band names** (`very easy / easy / normal / hard /
  very hard`) on the readout, if §5.2's formula is adopted.
- **`&Create Deck...`** — the startup screen's route into the Deck Builder,
  which we can honour: our Deck Builder is a screen away and the gauntlet
  is not mid-duel, so this is a scene change and a re-enumeration, not a
  new feature. The 1997 rule that comes with it: **re-enumerating the
  decks re-shuffles the run** (§1.5).
- **Deck validation per round** with `@GAUNTLETERRORS`' own words, which
  `game/deck_builder/deck_model.gd` already holds two of.

**Not in scope, deliberately:** `&Save gauntlet` / `&Load gauntlet...`.
See §5.5.

---

## 5. What the sources cannot settle, and what I would choose instead

### 5.1 Which gauntlet — the shell page's or the startup screen's?

The sources describe two, and they disagree: the shell page has a
`Num opponents` spinner and a `Best of:` spinner and a five-band computed
difficulty; the startup screen has neither spinner, a hard cap of 20, and
two Match Sizes. **They are different screens from different eras of the
same product and no source reconciles them.**

**I would build the startup screen's version, plus the shell page's
`Num opponents`.** Reasons: it is the one the decompilation implements, so
every behaviour is checkable rather than reconstructed; its Match Size
pair is the one the manual describes in prose (p.156); and `Num opponents`
is the single parameter whose absence would hurt — a run whose length is
"however many decks are in the folder" is not a design, it is an
accident of the filesystem. **`[QoL]`**: `Num opponents` defaults to
`min(decks, 20)` and may be lowered, never raised past 20.

### 5.2 `Gauntlet difficulty: %3d (%s)` — the number is not in any source

We have the format, the five band names, and exactly one input rule
(manual p.138: ante `+1`). We do not have the formula, the range, or the
band boundaries. The shell binary that computes it is not in the
decompilation.

**Options, honestly:** (a) omit the readout; (b) invent a formula and label
it; (c) show the Enemy Level's own name where the original showed a
number.

**I would take (b) and label it `[QoL]`**, because the readout is the only
thing that tells a player their choices have a cost, and a run configured
without one is a strictly worse pre-duel screen than the original's. The
smallest formula that honours the one rule we have:

```
difficulty = enemy_level (0..3) × 3            Apprentice 0 … Wizard 9
           + (ante ? 1 : 0)                    manual p.138, verbatim
           + (best_of == 1 ? 2 : 0)            one duel is more swingy
           + floor(num_opponents / 4)           a longer run is harder
bands: 0-2 very easy · 3-5 easy · 6-8 normal · 9-11 hard · 12+ very hard
```

Every term but the first two is mine and must say so at the site. Write it
as a `static func` with the five band names from `@SHELLPAGE_GAUNTLET`
(`Program/UIStrings.txt:64-68`) so the words at least are the original's.

### 5.3 Does the AI sideboard between the duels of a gauntlet match?

Unanswerable and already answered by us: `MatchScreen`'s class doc records
that the AI does nothing between duels and that `docs/ROADMAP.md` carries
the open half (M4 phase 2.x, "AI SIDEBOARDING — designed, NOT BUILT").
The gauntlet inherits that unchanged. **No new decision.**

### 5.4 Where do `Num opponents` and `Sideboard between duels` live?

The 1997 answer is the shell page for both; the startup screen has
neither. Since we are not building a shell, **both go in the gauntlet
setup screen** with `Ante` and `Match Size`, and the Gauntlet Options
window carries only the four things `@DIALOG_GAUNTLETOPTIONS` names.
Splitting one run's parameters across a screen and a modal for fidelity to
a screen we do not have would be fidelity to nothing. **`[QoL]`, and small.**

### 5.5 Saving

`MTG Gauntlet Save Game` is a real 1997 artefact and a real feature, and
we have no save/load anywhere in this project — not for a duel, not for a
match, not for Shandalar. **Out of scope for the gauntlet**, and it should
land as one design across all three when M5 needs it. What the gauntlet
should do now is what the duel already does: **log its seed**, so a run is
reproducible from a bug report even without a save file. `&Load
gauntlet...` is listed and greyed if the setup screen has room, on §6.1's
own precedent.

### 5.6 The opponent order's one oddity

The original shuffles only the first `min(n, 20)` decks, so deck 21 is
unreachable. That is almost certainly the 1997 bug the FAQ's *"The random
selection of opponents in the Gauntlet is now fixed"* is about — and it
may be what was fixed, or what was left. **I would sample the 20 from the
whole folder** and note it as `[QoL]`: with five decks on disk it is
indistinguishable, and with fifty it is the difference between a mode and
a bug.

### 5.7 What "Difficulty" and "Enemy Level" mean when both seats are ours

The original's gauntlet is one human against a machine. Our duel screen is
hotseat-capable and our `DuelConfig` has a pilot per seat. **The gauntlet
is single-seat by definition** — `Defeat as many opponents in a row as
possible` — so seat 0 is the human, seat 1 is the `AiProfile` from Enemy
Level, and the mode does not offer the hotseat choice. `MatchState`'s
`human_seat` already handles the general case.

---

## 6. Should it be built, and at what size?

**Yes, and it is small — because we accidentally built most of it in
August.** The honest sizing:

| Slice | What | Size | Layer |
|---|---|---|---|
| 1 | `GauntletState` + tests | **S** (an afternoon) | game (pure) |
| 2 | `GauntletScreen` + the round window + one signal on `MatchScreen` | **M** (a day) | UI |
| 3 | `GauntletOptions` + the setup route + the main-menu button | **M** (a day) | UI |
| 4 | The 1997 finish (announcements, difficulty readout, Create Deck, per-round validation) | **S** | UI |

**M in total, not L.** The reason is worth stating plainly, because it
changes the recommendation: the gauntlet is not a mode with its own
progression. It has no collection, no purse, no unlocks, no persistent
record between runs — §1.6 checked for all four and none of them is in any
source. It is **`MatchScreen` with an opponent list, a round counter and a
session tally**, and `MatchScreen` is 332 lines that already do the harder
half (the between-duels window, the sideboard step, the seed split, the
headless path).

**What makes it worth doing anyway** is not size, it is what it gives the
project:

1. **It is the only 1997 mode we are missing.** Our main menu is `Magic
   Battle / Deck Builder / Options / Help / Exit` against the original's
   `Solo Duel / Gauntlet / Sealed Deck / Duel Opponent`. Solo Duel is
   built; Duel Opponent is network play and will never be; Sealed Deck
   needs a booster-pack simulator and a tournament ladder and is a real L.
   **The gauntlet is the cheap one, and it takes the count from one of
   four to two of four.**
2. **It is the first thing that gives a built deck somewhere to go.** The
   Deck Builder ships, `DeckFormat` ships, proxies ship, and the only
   consumer is a single duel. A gauntlet is the reason to build a
   sixty-card deck.
3. **It is a load test for the match code we shipped.** `MatchState` and
   `MatchScreen` have never run more than one match end to end. A headless
   twenty-round gauntlet is a test we do not have.
4. **It is M5's rehearsal.** Shandalar is a run of duels against an ordered
   opponent list with a record and an ante economy. The gauntlet is that
   minus the map — the same outer loop, in a mode we can finish in a week
   instead of a milestone.

**Where I would put it**: after the current duel work, before M5, and only
once §5.1's decision is confirmed by the owner — it is the one place this
design chooses between two 1997 screens, and the choice shapes slice 3.

---

## 7. Tier 3 — what the reimplementations do, labelled as theirs

**s30 has no gauntlet.** Searched the whole tree: the word appears only in
`assets/text/*` (which are the 1997 tables it ships verbatim, including
every string quoted above), in `shandalar-faq.txt` (the 1997 community FAQ
it also ships), and in `card_tiers.toml` (*Gauntlet of Might*). Its Go
code has none. **So there is no `[s30]` design to adopt or reject here**,
which is unusual for this project and is why this document leans on the
decompilation instead.

**Manalink 3 kept the gauntlet and grew a mode on top of it.** Its
`&Challenge Mode` checkbox replaces the 1997 `&Ante` on the gauntlet page
(`Program/Text.res:2845`), and `src/functions/challenge_mode.c` reuses the
game's own `gauntlet_round` global (`src/manalink.h:64`) as its progress
counter across a hundred-odd scripted rounds. **That is entirely
Manalink's and is not to be mixed in** — but it is evidence for one thing:
the 1997 gauntlet's round counter is a real, addressable game global, and
a mode built on it is the natural extension. If this project ever wants a
scripted ladder, this is where it hangs.

**Our own Deck Lab `--gauntlet`** (`tools/simulate.gd`, `docs/deck-lab.md`)
is a round-robin measurement harness and shares nothing with this but the
word. It keeps its name.

---

## 8. What this pass did not do

- **No game code.** Not one line under `game/`, `engine/` or `cards/`.
- **The manual pages were not re-read** — it is not in the repo. The two
  gauntlet quotations (p.138, p.156) are taken from where this project
  already recorded them (`docs/duel-todo.md` §6.19 and
  `game/duel/match_state.gd`). **Anyone with the scan should read
  pp. 135-140 and 155-158**: they are the only prose description of the
  shell's gauntlet page that exists, and they would settle §5.1 and §5.2
  outright.
- **`Duel.hlp` was checked and has nothing** (§1.9). That check is
  finished; do not run it again.
- **The gauntlet save format was not reverse-engineered** (§5.5).

---

## 9. What building it PROVED (2026-09-02, same day)

The design was implemented in four slices without re-deriving anything.
Everything above held except where this section says otherwise, and the
whole of it landed on a full-suite-green baseline with no change to
`engine/`, `cards/` or the duel screen.

**§5.1's decision — TAKEN, the design's own recommendation.** The duel
program's screen (`@DIALOG_GAUNTLETOPTIONS`: `Best of Three` /
`Best of One`, four Enemy Levels, the cap of twenty) **plus** the shell
page's `&Num opponents:` and `Side&board between duels`, and the shell
page's `Gauntlet difficulty: %3d (%s)` readout with §5.2's `[QoL]`
formula behind it. Reversing it later would mean a `&Best of:` spinner
and a shell page; nothing else built would move.

**Three things the design got wrong or left short.**

1. **§2.2's diagram and §4's slice 2 disagree, and slice 2 is right.**
   The diagram shows the round window after EVERY duel, with all four
   branches including `The match continues...`; slice 2 calls it "the
   between-matches window", and §1.5 says the mid-match window is the
   ordinary `@DIALOG_ENDEXP1DUEL_*` one `MatchScreen` already builds.
   Both cannot be true without two windows after one duel. **Built as
   slice 2 and §1.5 describe it**, so `CONTINUES` is composed, tested and
   never rendered — recorded in `GauntletScreen`'s class doc rather than
   quietly dropped.
2. **The round window's first line is about the DUEL, and the design
   never says where that comes from.** `@GAUNTLET`'s entries 1-3
   (`Congratulations!` / `Too bad` / `Oh well...`) name the duel just
   played, and `MatchState` recorded no such thing — a best of three that
   is won, drawn, drawn is OVER and WON while its last duel was a draw, so
   deriving it from the match winner is wrong in exactly that case.
   `MatchState.last_winner` was added for it.
3. **"`MatchScreen` needs exactly one change" is one change and one
   FLAG.** Emitting `match_finished` only when somebody is listening reads
   well and is wrong: a GUT test that merely WATCHES a signal is a
   connection, so the test pinning the standalone path broke it. The
   signal now always fires and `reports_to_owner` decides the behaviour.

**One divergence of ours, marked at the site.** The session record
(`wins/losses/ties`) counts duels and is folded in when a MATCH ends
rather than when each duel does — `GauntletScreen` sees matches, not
duels, and the round window is the only reader, so the number displayed is
identical. A second signal would make it live; it would also be a second
change to a shared file for no visible difference.

**Two defects only a screenshot could find** (both fixed, and the recipe
earned its keep): `Run the gauntlet` and `Quit Gauntlet` had their last
letter sitting ON the 1997 button art's inner rule —
`OriginalDialog.button` floors at 96px, the width `OK` wants, so
`GauntletOptions.fit()` now measures the label; and the options window
opened on a black void, because a gauntlet reaches its first duel through
no other screen and therefore had no ground of its own. **The button
tightness is project-wide** (`Continue match`, `Sideboard...` are as
close); only the gauntlet's own were fixed here.

**What the sources said and the code already did.** `wins_needed()` was
already `best_of / 2 + 1`, so `Best of &One` needed no arithmetic;
`AiProfile` already shipped the four Enemy Levels under the original's own
names; `MatchScreen`'s between-duels window, sideboard step, seed split
and headless path all carried over untouched. The design's "size M, UI
only, mostly wiring" was accurate.

**Still owed** (the design's own slice 4, none of it load-bearing): the
three `@DIALOG_STARTEXP1MATCH_GAUNTLET` next-opponent announcements,
`&Create Deck...` with its re-enumerate-and-reshuffle rule, and the other
three `@GAUNTLETERRORS` opponent-deck messages — the first,
`Opponent's deck %s is invalid.`, is wired and ends the run.

---

## 10. Slice 4, and what IT proved (2026-09-02, later the same day)

Everything §9 listed as owed is now built, and the whole of it landed on a
full-suite-green baseline with no change to `engine/`, `cards/`, the duel
screen or the match screen.

**The three announcements are a WINDOW of ours, not a screen of theirs.**
`@DIALOG_STARTEXP1MATCH_GAUNTLET`'s three lines sat, in 1997, on the
pre-match VERSUS screen — `@DIALOG_STARTEXP1MATCH`
(`Program/UIStrings.txt:144-147`) is that screen's own two strings, `vs.`
and `playing with %s`, and `Provenance.md` records the 240x170 `Face_*`
portrait set as its art. We have no versus screen and slice 4 does not owe
one; what it owes is the three SENTENCES. They are now a small window
before each match — the announcement over the opponent's name, on the same
stone the round window wears — and `vs.` / `playing with %s` are left for
whoever builds the screen they belong to. It goes AFTER the round window
rather than replacing that window's `Your next duel is against %s.`: they
are two moments, and the last round's window has no announcement after it
at all.

**The one thing no source settles, decided and marked.** A run of length 1
is at once the first opponent and the final one. `&Num opponents:` is what
makes such a run reachable and the decompiled startup screen is not in the
survey, so the choice is ours: `first`, because the announcement is made
as the run BEGINS. `GauntletState.announcement_for_round` carries the
reasoning and a test pins it.

**§4's fourth slice-4 bullet is WRONG, and this is the evidence.** It asks
for *"deck validation per round with `@GAUNTLETERRORS`' own words"* as
though all four opponent-deck messages were producible. **Three are.**
`Opponent's deck %s is invalid. Wrong version number.` is not, because
**neither deck format this project reads carries a version number**:

* all 55 shipped 1997 `.dck` files (`shandalar-src/Program/decks/`) open
  with a bare name line (`Seer (Ub, Type 1)`), a blank line, and then
  `.<id><TAB><count><TAB><name>` rows — no version field anywhere;
* our own `.deck` / `.dec` text has none either;
* the only numbered revision anyone has is **Manalink 3's**, whose
  `save_deck` writes an eight-line `;`-prefixed header with `;%d\n` for
  `global_deck_revision` (`shandalar-src/src/deck/deckdll.cpp:5522-5545`)
  — Tier 3, a format we do not write and the 1997 game never read.

The string is kept as a constant with that obituary on it, the way
`WON_DUEL` and `CONTINUES` already are, and a test asserts that nothing
can return it. Wiring it would have meant inventing a condition.

**`&Create Deck...` costs one divergence, and it is marked at the site.**
The original came BACK to its startup screen with the parameters still set
(control `0x44e` → `DeckBuilderMain(hwnd, 0x18, 1)` → re-enumerate and
re-shuffle); ours is a scene change to the Deck Builder, which exits to the
title. The re-enumerate-and-reshuffle rule then holds **by construction**
rather than by implementation — the next entry into the gauntlet reads the
deck folder afresh in `_ready` and shuffles it afresh in `begin_run`, so no
path carries a stale list or a stale order past a visit to the builder.
Honouring the return would need the Deck Builder to know who sent it, which
is the same missing piece that keeps `MatchScreen`'s `&Edit deck...`
greyed, and is a bigger change to a shared 115 KB screen than slice 4 is
worth.

**One thing only a screenshot could find, again.** The announcement window
was built at 430x190 by analogy with the round window's 430x250, and the
capture showed a hand's width of bare rock between the opponent's name and
the OK button — the round window carries five lines in that height and this
one carries two. It is 430x150 now. (The recipe has now earned its keep
three times on this mode.)

**What the run proved on real data.** The windowed capture ran against the
actual deck folder and stopped at round 1 with `Opponent's deck New Deck is
invalid.` — a 44-byte `New Deck` left in `user://decks` by an earlier Deck
Builder session. That is the validation working exactly as specified
(§1.7, case 4), on a file nobody planted for it. Worth knowing that an
empty deck a player saves can end their next gauntlet before it starts;
that is 1997's rule and not a defect, but it is the kind of thing a player
will report.

---

## 11. Your own deck was never checked (2026-09-02, the review)

`_apply_options` loaded your deck strictly and, when the load failed,
**kept the config's default and started the run anyway** — with the
comment `unreadable: keep the default deck`, as if that were a fallback
rather than a substitution. In a gauntlet reached from the title the
config's default is the hotseat White Knights, so a player who picked a
deck holding one proxy (the strict load reports it as an error, exactly
as the setup screen's gate does) was dealt a different deck with no word
said. `<random deck>` could draw the same unplayable file and go the same
way.

Now `GauntletState.your_deck_problem` answers the same three tests as the
opponent's in the `Player's deck %s is invalid.` strings (entries 2, 4
and 5; `wrong version number` has the same obituary as the opponent's),
`<random deck>` draws only from decks that pass — the setup screen's
`_playable_paths` rule — and earns entry 1 when nothing on disk does. A
refusal is a window on the same stone as the announcement whose OK
re-opens the options window, which is the original's own shape: its
message box returned to the startup screen with the parameters still set
(§1.7, case 4). `GauntletScreen.last_refusal` keeps the line so a
headless run can be asked; `tests/ui/test_gauntlet_screen.gd` pins all of
it, including that eight seeds of `<random deck>` over a pool with two
bad decks and one good one draw the good one eight times.

---

## 12. The roster after the 1997 decks arrived (2026-09-02, later)

`docs/decks-1997.md` put 312 decks under `decks/`, and §1.4's rule —
every deck file in the directory is an opponent — met a directory that
now holds 101 decks (under `decks/tournament/`, `decks/community/` and
`decks/extended_community/`) whose cards this pool does not all hold. A
strict load reports each as an error, so each one dealt is a round
refused (§1.7, case 4), and dealt blind, a hundred in a pool of three
hundred ended most twenty-round runs on a deck nobody chose.
**[QoL]** `GauntletScreen.default_roster()` is now the 1997 rule less the
decks a round would refuse the moment it drew them (`opponent_deck_problem`
over a strict load) — 216 decks: the five starters, every MicroProse deck,
and the 54 proxy-free non-MicroProse decks (five tournament lists, 48
community decks, one Old School reference list). A
roster handed in explicitly is taken as given, so the per-round check
still runs and its four messages are still reachable. The `Your deck`
picker on the options window carries a heading per provenance group, as
the setup screen's does. Pinned in `tests/unit/test_decks_1997.gd`.
