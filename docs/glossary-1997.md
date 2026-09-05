# The 1997 glossary — the original's words for things

The owner's instruction: **our names for things should be the 1997
manual's names, not ones we invented.** This file is the mapping, and it is
the reference every later pass should reach for before naming a control,
writing a prompt, or labelling a window.

Companion to `docs/duel-todo.md`, which turns the mismatches into work
items (see its §9 for the naming to-dos in visibility order).

## Sources and citation form

| Cite | Source | Authority |
|---|---|---|
| **manual p.N** | the 1997 MicroProse instruction manual. "Computer code and manual © 1997 MicroProse Software, Inc." Two chapters cover the duel: **ch. 8 "The Duel"** (pp. 59-106, the rules) and **ch. 9 "Dueling in Shandalar"** (pp. 107-132, the screen). A Glossary runs pp. 159-186 and an "Appendix: Sequence of Play" pp. 187-194. | PRIMARY |
| **Duel.hlp** | `../shandalar-src/Duel.hlp` — the game's OWN shipped help file, the "Dueling Help" the manual points at (readable with `strings`); contents list at `../shandalar-src/Duel.cnt:686-701` | PRIMARY; defines each screen part |
| **UIStrings.txt:N** | `../shandalar-src/Program/UIStrings.txt` — the 1997-era string table. NOT the top-level copy, which is Manalink 3 | PRIMARY for exact on-screen wording |

**Page numbers are PRINTED pages** (the folio on the page). In the owner's
scan, `printed = PDF page − 6`. The manual is copyrighted and stays out of
the repo; only these citations and our own prose live here.

## How to apply a name

In the owner's priority order:

1. **User-facing text first** — prompts, labels, window titles, button
   text, log lines. These are what the player reads, and they are cheap to
   change. Use the manual's word.
2. **New code** — anything written from now on uses the manual's word from
   the start.
3. **Existing identifiers** — proposed as to-do items with a size, never
   swept. A rename reaching into `engine/` is out of scope for duel work.

**One exemption, decided by the owner: PHASE NAMES.** We keep the modern
step vocabulary (`DECLARE_ATTACKERS`, `COMBAT_DAMAGE`, `END`, `CLEANUP`)
because "Declare Attackers" is clearer than "Main phase (combat)", and
keeping the modern words *while publishing this mapping* is what makes the
faithfulness transparent. §3 is that mapping. Nothing in `duel-todo.md`
renames a step or changes the phase strip's slot count.

---

## 1. The screen — regions, windows, panels

The screen is the **Dueling Table** (manual p.110: *"In Shandalar, all
duels are conducted on the same table. Vital functions are performed
automatically, and the layout is for the most part not configurable."*).
Its labelled figure is on **p.111**, captioned **"The field of honor"**,
with thirteen callouts:

> left rail, top→bottom: `Opponent` · `Showcase` · `Phase Bar` ·
> `Library` · `Graveyard` · `Life Register` · `Mana Pool`
> top: `Creature in play` · `Opponent's Territory`
> right: `Opponent's Hand` · `Land in play` · `Your Hand` ·
> `Your Territory`

| 1997 term | The manual's own words | p. | We call it | Where ours lives |
|---|---|---|---|---|
| **Dueling Table** | the whole duel screen | 110 | duel screen | `DuelScreen` (`game/duel/duel_screen.gd`) |
| **Territory** | *"By far the largest areas of the dueling table are your territory and your opponent's. The lower territory is yours, the upper belongs to your adversary. These areas contain all of the cards in play."* — and its origin: *"your half of the playing surface, which is called your territory"* | 111, 60 | board half | `_board_half()`, `_half_rows` (`duel_screen.gd:100,1759`) — **top rename candidate**; the word is user-facing in the options too (`Your &territory background`) |
| **The field of honor** | the figure's caption for the whole table | 111 | — | flavour name; good for a loading line, not a control |
| **Showcase** | *"To the left of the Phase Bar, in the center, is a big card… this is the Showcase."* · *"The Showcase is a display only; it has no other function."* | 117 | enlarged card / big card / card preview | `CardPreview` (`game/duel/card_preview.gd`), `_preview_dock` — **rename candidate** |
| **Phase Bar** | *"runs from top to bottom of the screen just to the left of the territories, is the central control for the progress of the duel"* · *"First and foremost, the current phase is always highlighted"* | 116 | phase strip / phase bar | `PhaseBar` (`game/duel/phase_bar.gd`) — ✔ same word. The highlight is the current phase; the red dots are Stops |
| **Combat Bar** | *"a miniature Phase Bar that appears during an attack… This bar has [seven] icons, representing the sub-phases of combat."* It **replaces** the Phase Bar during combat. (The printed manual says five; `Duel.hlp` says seven and the art draws seven — §3) | 117 | Combat Bar | `CombatBar` (`game/duel/combat_bar.gd`) — ✔ same word |
| **Situation Bar** | *"Between the two territories (usually) is the Situation Bar. This is a reminder to you of what's going on and what you need to do. Depending on what else is on the screen, this bar moves so as to always remain visible."* | 115 | message bar / prompt bar | `_prompt_label` + `msg_popup` (`duel_screen.gd:1687-1727`) — **rename candidate**; ours is pinned, never moves |
| **Library** | *"two piles of face-down cards… the dueling decks, each of which is now considered to be a player's library"*; *"The number of cards left in your library is represented — inexactly, as in real life."* | 118 | library | `MtgPlayer.library`, `_lib_labels` — ✔ same word; we print the exact count, the original hid it behind a right-click |
| **Graveyard** | *"Next to each library is an area for discarded cards — a graveyard"*; *"your discard pile, which is always face up"* | 118, 60 | graveyard | `MtgPlayer.graveyard`, `_grave_icons` — ✔ same word |
| **"out of play" area** | *"Cards which are removed from the game entirely do not go into the graveyard. (They're stored in what's called the 'out of play' area.)"* | 118 | exile | `Mtg.Zone.EXILE` — **confusing to a modern player**: here "removed from play" means EXILED, not "left the battlefield". Keep `EXILE` in code |
| **In Play** | *"Cards that have been played in your territory or in your opponent's territory are considered 'in play.'"* | 171 | battlefield | `Mtg.Zone.BATTLEFIELD` — CR's word; keep |
| **Life Register** | *"The area of the dueling table where the life total is tallied."* Holds poison counters; flips to the opponent's face | 119, 174 | life panel / life numeral / life button | `_life_buttons`, `_poison_labels` — **rename candidate** |
| **Lich Register** | its own help topic; `UIStrings.txt:678` carries `%s life points (opponent is Lich'd)` | — | — | **we have none** |
| **Duelist's Face** | the opponent's portrait; *"You can right-click on either life register and select **Flip to Face** if you'd rather see your opponent's face."* And it is the **player-target click**: *"If your opponent is a valid target, her Life Register flips over. To target your opponent, click on the face instead of a card."* | 119, 121 | — | **we have none**; our life button is the player-target click, which is the same idea without the portrait |
| **Mana Pool** | *"Between the Life Registers and the Phase Bar are the two Mana Pools."* Six colour rows, each a round button + a count | 119 | mana pool / mana column | `ManaPool`, `_mana_column()` — ✔ same word |
| **Damage Marker** | *"a damage marker — a yellow 'card' on or near the target of that damage"*, and it is a CLICK TARGET: *"click on any valid target — a card, a damage marker, or whatever"* | 119, 121 | damage indicator | `MiniCard`'s dagger + number — ✔ we draw it, but **ours is not an object and cannot be targeted** |
| **effect cards** | *"those effect cards (the temporary yellow cards that pop up all the time)"* — normally hidden, revealed by `Show Invisible Effects` | 112 | — | **no first-class ephemeral-effect object at all** |
| **Hand** (window) | *"A small window floating over your territory contains representations of the cards in your hand. Only the title bar of your opponent's hand is visible; this is to keep you aware of how many cards are in that hand."* Draggable by its top bar; a **revolving** scroll when it overflows; the count is in the title | 114 | hand window | `StackHand`, `FanHand` — ✔ `Your hand (N)` matches exactly; **`Opp Hand (N)` is s30's wording** and should be `Opponent` (`UIStrings.txt:155`) |
| **Spell Chain** (window) | *"A spell in the process of being cast, all of the interrupts targeting that spell…"* Callouts: `Original Spell`, `Spell's Target`, `Interrupt`, `Interrupt's Target`. Resolves **LIFO** | 121-123 | the stack / spell chain | `MtgGame.stack`, `_chain_box` — ✔ the UI already says spell chain; the ENGINE should keep `stack` (correct CR) |
| **Combat** (window) | *"As soon as you add the first creature to the attack, the Combat window opens. Your attackers line up on your side, and the space on the other side is reserved for (potential) blockers."* Title bar: `Your attack` | 126 | Combat window | `CombatWindow` (`game/duel/combat_window.gd`) — ✔ same word and the same title |
| **Duel Options** window | body text calls it the *"Dueling Options"* window; the title bar reads `Duel Options` | 113 | — | **we have none** (our `game/options_screen.gd` is a different, non-1997 panel) |
| **Dueling Help** | *"Any time during a duel, you can right-click on any part of the Dueling Table… One of the options is Help… you get information about whatever you clicked on, plus links to more details and other topics."* Context-sensitive and hyperlinked | 14, 112 | — | **we have none** |
| **cue cards** | *"the tiny hints that pop up when you position the mouse cursor over an active location"* | 113 | tooltip | Godot `tooltip_text` — user-facing option text should say **cue cards** |
| **small cards** | the option labels' word for the card representations **in play**, as opposed to the Showcase card (`Show abilities on small cards`) | 113 | mini card | `MiniCard` — ✔ close enough; the option text must use the original's phrase |
| **mini-menu** | *"right-click on any active area on the table… to open a mini-menu of options"* | 110 | — | **we have none** — use this word when context menus land |
| **window icon** | *"click on the window icon in the center area of the Phase Bar"* — restores a minimised Spell Chain or Combat window | 122, 126 | window icon | `DuelScreen._window_icon` — ✔ built for the Combat window (`Winbk_Attackmin`, 39x70, drawn 1:1 in the blank centre band it was clearly authored for). The Spell Chain still has no minimise |
| **ID tags** | *"each card's unique ID code"*, toggleable, *"useful when you need to determine exactly which of several otherwise identical cards is the target"* | 112 | instance id | `CardInstance.id` — the id exists; nothing displays it |
| **Standard / Advanced Layout** | Standard *"includes a permanent Showcase, but the territories are slightly smaller"*; Advanced *"streamlines the dueling area. The Showcase is removed (though it appears when necessary)… to allow the largest possible territories"* | 113 | — | **we have none**; ours is Standard |

## 2. Buttons, commands and gestures

| 1997 term | The manual's own words | p. | Ours |
|---|---|---|---|
| **Done** | *"signals that you're finished with the current phase or spell, or that you do not wish to take advantage of the current opportunity to use fast effects. **However, this option does not simply move you on to the next phase or action.** Rather, it tells the 'referee' that you do not intend any action until (1) you reach a phase that has a Stop on it, (2) an action or decision is required…, or (3) you are able to use a fast effect. (Note that 'able to' means that you have a fast effect handy **and** you have the mana available to use that effect.)"* | 112 | **Return / Enter is now this exact instruction** (`DuelScreen._on_pass_turn`, 2026-08-31), per p.116's key table. Our Done BUTTON still passes ONE priority — finer than either 1997 verb, kept as **[QoL]**, and the nearest 1997 word for it is `Go To` (§6.3) |
| **Cancel** | *"a convenient way to cancel a spell or effect"* — and in the rules sense: *"The spell goes back into your hand as if nothing had happened, but the mana in your mana pool is still there"* | 112, 67 | `DuelScreen._on_escape` + the Situation Bar's **Cancel button**, which appears whenever `_can_cancel()` is true (§6.11, 2026-08-31). Esc and the button are the same door, and each press peels ONE layer |
| **Go To** | *"ends the current phase and moves you on to the next one"* | 112 | `DuelScreen._order_next_phase` / `Advance.NEXT_PHASE` — ✔ built as `@MENU_TERRITORY`'s `Go to: next phase` (§6.3, 2026-08-31); the other thirteen `Go to:` entries are Run to destinations |
| **Run to** | phase mini-menu; same as left-clicking a phase icon — skip forward to that phase | 116 | `DuelScreen._order_run_to` — ✔ built, both bars, with the manual's three exceptions and the forgotten destination |
| **Mark** | phase mini-menu → places a **Stop** | 117 | `@MENU_PHASEBAR`'s `Mark this phase to always stop`, built as a TOGGLE — the 1997 table ships no unmark string |
| **Stop** | *"a lasting instruction that you do not want the duel to pass that phase… that phase does not end until you tell it to manually; it cannot pass automatically."* And why it matters: *"there is no way to 'back up' a phase… This is what Stops are designed for."* · *"A Stop on your opponent's Main Pre-Combat sub-phase is always a good idea."* `Duel.hlp` calls its marker a **Stop marker** | 116-117 | `PhaseStops` (`game/duel/phase_stops.gd`) — ✔ same word; the RED DOT on either bar is the Stop marker |
| **Concede** | *"A player can concede a duel at any time. The duel ends immediately and the other player wins."* + *"You must confirm this decision."* | 165, 112 | **we have none** |
| **Arrange Cards** | *"straightens up the cards in play in the territory where you right-clicked. This has no effect on the duel, it just makes things neater. (You can also double-click on a territory to do this.)"* | 111 | `BoardOrder` + `ArrangeButton` — ✔ built as an on-demand TOGGLE (§2.3, 2026-08-31): the sidebar control arranges the whole table, `@MENU_TERRITORY`'s two entries one territory each. The `DblClk` gesture is not wired |
| **Flip to Face** | life-register mini-menu | 119 | — |
| **Expand** | Showcase text-area toggle, *"causes the text area to grow… to display the entire card text"* | 117 | — (our preview steps the font down instead) |
| **Show Full Card** | card mini-menu → display in the Showcase; *"You can also double-right-click"* | 113 | hover feeds the docked preview |
| **Original Type** | *"shows you what this card was when it was cast, before any spells and effects changed it"* | 113 | — (we have `data` vs `cur_*`, nothing shows it) |
| **Don't Auto Tap** | *"marks a land to be ignored — not tapped for mana — when you auto-cast any spell or effect. The only way to tap a **locked** land is manually, by clicking on it."* | 113 | — |
| **auto-cast** | *"you can 'auto-cast' a spell by double-clicking on it… you momentarily give up control over which of your mana is used."* For an X spell it puts in **all** available mana | 113, 115 | our wishlist calls this "auto-tap mana"; the original's word is **auto-cast**, and it is a 1997 feature, not QoL |
| **Minimize / restore** | Spell Chain and Combat windows minimise from their upper-right corner and restore from the **window icon** | 122, 126 | StackHand's ▲/▼ collapse is the nearest thing |
| the mouse vocabulary | *"'Click' means to click the left mouse button… 'Right-click'… 'Drag' means to hold down the LMB while you move the mouse… 'Double-click' means to click the LMB twice rapidly."* | 22, 29 | — |
| the keyboard contract | *"Esc is just like clicking the Cancel button."* · *"Return has the same effect as clicking the Done button."* · *"If there is only one button, pressing the Spacebar is the same as clicking on that button."* **These are the only duel hotkeys the manual documents.** | 116 | ✔ all three, verbatim (§6.11, 2026-08-31): Esc is the Cancel button's own action; Return is Done in every mode (and the manual's standing instruction in NORMAL, p.112); Space acts only while Done is the bar's ONLY button |
| **referee** | the manual's word for the rules engine: *"the computer — acting as referee"* | 112, 116 | the engine — a good word for log lines and refusals |

## 3. The phases — the mapping (naming exempt, by the owner's decision)

The manual names **six** phases and is explicit that combat is not one of
them (p.60):

> *"each player's turn is divided into six smaller parts called phases…
> The phases always take place in the same order: 1) Untap 2) Upkeep
> 3) Draw 4) Main 5) Discard 6) Cleanup"*

Combat lives inside Main (pp.62-63): *"the main phase is split into three
parts: **Main Pre-Combat** … **Combat** … **Main Post-Combat**"*, and the
Glossary confirms it (p.165): *"Combat — When dueling in Shandalar, the
second of the three 'sub-phases' of the main phase."* Main is also where
the land drop and the single attack live (p.62): *"you can: cast spells,
put one land into play, and make one attack. You can do these in any
order."*

So the Phase Bar shows **eight** icons per seat, because Main is drawn as
its three parts. The strip's own tooltips
(`UIStrings.txt:706` `@CUECARD_PHASEBAR`) name the slots:

| slot | icon (from `assets/original/phase_bar.png`) | 1997 tooltip | our `Mtg.Step` |
|---|---|---|---|
| 0 | a hand turning a curved arrow | `Untap phase` | `UNTAP` |
| 1 | a hammer over an anvil | `Upkeep phase` | `UPKEEP` |
| 2 | an open hand, palm up | `Draw phase` | `DRAW` |
| 3 | a crescent moon (the phases-of-the-moon pun) | `Main phase (precombat)` | `MAIN1` |
| 4 | a sword in a shield | `Main phase (combat)` / yours: `Main phase (declare combat)` | `COMBAT_BEGIN` … `COMBAT_END` |
| 5 | the same crescent, mirrored | `Main phase (postcombat)` | `MAIN2` |
| 6 | an open hand, palm down | `Discard phase` | — (our discard happens inside `CLEANUP`) |
| 7 | a broom | `Cleanup phase` | `END`, `CLEANUP` |

Sixteen slots in all — *"The top half of the bar represents the phases in
your opponent's turn, while the lower half represents your turn"*
(`Duel.hlp`) — with the **window icon** in the blank band between them.
That is exactly what we already render.

Inside slot 4, the **Combat Bar** shows **seven** icons — one per tooltip,
per `Duel.hlp`'s own topic **Combat Bar**: *"This bar has seven icons,
representing the sub-phases of combat"*, followed by the list below. (The
printed manual, p.117, says **five**; it is the only source that does. The
help file names seven, `@CUECARD_PHASEBAR` carries seven combat tooltips,
`@MENU_TERRITORY`'s `Go to:` list names the same seven stops, and
`Winbk_Phasecombat.pic` draws seven icons. Corrected 2026-08-31 —
`docs/duel-screen-design.md`, twenty-ninth pass.)

| Combat Bar icon | `Duel.hlp`'s name for it | 1997 tooltip | our `Mtg.Step` |
|---|---|---|---|
| a sword, hilt up | Declare Attackers | `Choose attackers phase` | `DECLARE_ATTACKERS`, awaiting the lineup |
| the sword with rays | Fast Effects | `Attacker fast effects phase` | `DECLARE_ATTACKERS`, lineup in |
| a shield | Declare Blockers | `Assign defenders phase` | `DECLARE_BLOCKERS`, awaiting blocks |
| the shield with rays | Fast Effects (2) | `Blocker fast effects phase` | `DECLARE_BLOCKERS`, blocks in |
| the shield split | Damage Dealing, Part 1: First Strike | `Resolve 1st strike damage` | `FIRST_STRIKE_DAMAGE` |
| a sword through the shield | Damage Dealing, Part 2: Normal | `Resolve normal damage` | `COMBAT_DAMAGE` |
| the mirrored crescent | Damage Dealing, Part 3: End of Combat | `Main phase (postcombat)` | `COMBAT_END` |

"Begin Combat" is not a Combat Bar icon — it is the Main-phase Combat icon
itself (p.190): *"when you click on [the Combat icon], you are only
announcing your intention to attack. The attack doesn't actually start
immediately."*

Reading the two tables together is the transparency the naming rule is
for. Four structural differences fall out, and each is a `duel-todo.md`
item rather than a rename:

1. The original has a real **Discard phase**; ours discards inside
   `CLEANUP` — but it now STOPS there and asks the player, in the
   original's own words (`§1.1`, DONE 2026-08-31).
2. ~~The original resolves first-strike and normal damage with a stop
   between them; ours runs both waves inside one `COMBAT_DAMAGE`.~~
   DONE 2026-08-31: `FIRST_STRIKE_DAMAGE` is its own step with a priority
   round after it, and it is skipped when nobody in combat has first
   strike (CR 510.5). The two rows above are now a true one-to-one
   mapping (`§1.6`).
3. The original pauses for **damage prevention** whenever damage is dealt
   (`§6.8`); we have no such window.
4. Our `END` step has **no 1997 counterpart at all**. The original put "at
   end of turn" effects at *"the very end of the cleanup phase"*, after
   the discard (`Duel.hlp`; manual p.64).

One curiosity worth keeping (manual p.117): *"Attentive players will
notice that there is an icon for the Cleanup Phase even though there are
no actions you or your opponent can take during this phase."*

## 4. Rules concepts — and where the 1997 word will mislead a modern player

| 1997 term | The manual's definition | p. | Modern / CR equivalent, and the risk |
|---|---|---|---|
| **fast effect** | *"Interrupts, instants, and non-continuous effects of permanents are called fast effects. Unless otherwise specified on the card, you can use fast effects during the upkeep, draw, main, and discard phases of any player's turn."* | 169 | **Broader than "instant."** It is the umbrella for everything playable at instant speed *or faster*, and explicitly includes drawing a card (p.62), tapping for a `{T}` ability (p.102) and every upkeep effect (p.129). Nearest CR notion: "playable any time you have priority". **We already say `Fast Effects?` in the status bar — keep it** |
| **interrupt** | *"Interrupts are the only effects that can be used while another spell is in the process of being cast, so only an interrupt can target a spell or counter another spell… an interrupt is always resolved immediately after it is announced."* And: *"you can interrupt an instant, but you can't instant an interrupt"*; *"you cannot respond to an interrupt"* | 55, 96 | **Abolished in 6th Edition — no CR equivalent.** A genuinely faster tier than instants. Our engine has no such split, so the `Interrupts?...%s` prompt collapses into `Fast Effects?...` (`duel-todo.md §6.7`). **Do not reintroduce the word in code** |
| **Batch / Stack** | *"A 'batch' or 'stack' is a series of fast effects that build on one another… resolved by the LIFO rule (Last In, First Out)"* | 163 | ≈ CR **the stack**. Careful: the manual uses *stack* as a synonym for *batch* and reserves **Spell Chain** for the UI window |
| **Fizzle** | *"If, for whatever reason, a spell fails, that spell is said to have 'fizzled.'… the card goes to your graveyard as if it had been countered, and the mana you spent is gone."* | 67 | ≈ CR "countered on resolution (all targets illegal)". Distinct from **Cancel**, which is a take-back with the mana refunded — **no CR equivalent at all** |
| **damage prevention step** | *"At any time when damage is done to a creature or player — and only when damage is done — a damage prevention step occurs. During this step… only damage prevention effects (including prevention, healing, and redirection) can be used."* · *"It takes place immediately when the damage is assigned and has precedence over anything else."* · *"Regeneration is not damage prevention. After the damage prevention step, if a creature still has lethal damage, it may be regenerated."* | 103, 188 | **No CR equivalent.** The single biggest 1997 rules structure we lack |
| **heal** | *"Healing… does not stop the damage from occurring. To heal is to repair damage already done."* | 178 | **No CR equivalent** (retroactive damage removal) |
| **bury** | *"must be sent to the graveyard; there is no possibility of regeneration"* | 163 | modern: "destroy; it can't be regenerated". Our `can_regenerate = false` is the same thing |
| **potential draw** | *"the single card that you would normally draw is represented in your hand by a face-down 'potential draw.' The card itself is still in your library."* Labelled `Draw a card` in the hand window; each actual draw is itself a fast effect | 130 | **No CR equivalent** |
| **null attack** | *"You can also attack with zero creatures; that's called a 'null attack.'"* | 63 | declaring no attackers — but *deliberately entering combat* |
| **local / global enchantment** | *"Targeted enchantments are called local. Non-targeted enchantments are called global."* | 56 | ≈ Aura / (world or global) enchantment |
| **Summon <type>** | the era's creature type line | — | our card data uses Scryfall's modern type lines; that stays |
| **mana burn** | *"if any unused mana remains in your mana pool when it empties, you lose 1 life for each one mana you didn't use"*, and the pool empties *"at the end of each phase and at the beginning and end of an attack"* | 176 | **removed from modern MTG (M10)**; `docs/mechanics.md:539` calls its absence an era choice, which is wrong for 1997 |
| **ante** | *"Before the duel begins, both players put up one or more cards from their decks as ante. In Shandalar, whoever wins the duel will get to keep the ante cards."* | 60 | ✔ same word; `Mtg.Zone.ANTE`, `MtgPlayer.ante` |
| **'Vantages (Ad- and Disad-)** | *"extra life, less life, or a guarantee that you'll go first… You never have more than two of these at any one time."* | 24 | Shandalar metagame modifier; adventure layer — **except** the one duel hook: *"Who goes first is determined at random — unless one of you has a first strike advantage"* (p.60) |
| **First Play / First Draw** | *"In every duel, one player plays first and the other draws first. Who does which is decided by the player who wins a coin toss (unless one player has a preexisting advantage). The player who gets First Play does not draw a card during her first turn."* | 110 | ≈ CR play/draw. **We have neither the choice nor the skipped draw** |
| **Mulligan** | *"If either player draws no land in this seven cards or draws all land, then that player has the option to declare a mulligan… shuffle her hand back into her deck and draw seven new cards… The other player has the option to do so as well… Each player has only one chance to redraw."* | 110 | conditional **7-for-7**, no card lost. Not Paris, not London. `docs/ROADMAP.md`'s planned rule is correct |
| **Advantaged Duels** | *"how much life you carry into a duel depends on how many cities you have mana links with"*; dungeons and castles carry *"strange overriding enchantments"* | 109 | adventure layer, but it is why starting life is not always 20. Only the standalone Duel gives *"both players… the traditional 20 life"* (p.157) |
| **Strict Enforcement** | *"This version of Magic: The Gathering enforces the official Fifth Edition rules."* · *"the new rulings… are ruthlessly enforced, and there is no room for negotiation"* | 108 | the ruleset target. Our engine cites modern CR, which is a deliberate divergence worth stating |

## 5. Terms we should NOT adopt

| Term | Why not |
|---|---|
| **interrupt** | no modern rules object corresponds, and our engine has no such tier — using the word would promise timing we do not implement |
| **Summon <type>** | our card data is Scryfall's modern type lines; changing them breaks the card pipeline for a cosmetic gain |
| **stack → spell chain** in `engine/` | `stack` is correct CR and the engine must stay legible to anyone who knows modern Magic. Keep `Spell Chain` for the UI window's title only |
| **batch** | the manual's own synonym for stack; ambiguous, and it has no modern currency |
| **the manual's phase names**, in code | exempted by the owner (§3) |
| anything from top-level `shandalar-src/UIStrings.txt`, `@ABILITYWORDSX`, `@ABILITYWORDS2`, `@ACTIVATE_TYPE`, the `mulligan to %d` strings | Manalink 3, not 1997 — see the provenance note in `duel-todo.md §6` |
