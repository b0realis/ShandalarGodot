# The small card, and everything it can wear

*Written 2026-09-04, read-only on game code. **§5's six defects were all
fixed later the same day** and each entry there says what was done; §3 and
§4 have been brought forward with them. Pictures:
`../shandalar-build/shots/card_states/` (one PNG per state, plus
`00_contact_sheet.png`) — see §6, they predate the fixes.*

Every card on the table, in a hand, in a pile, in the graveyard viewer and
in the Deck Builder's grid is the same widget: **`MiniCard`**
(`game/duel/mini_card.gd`), 132x106, never rescaled, and the only transform
it may wear is the 90° tap turn. The original's own word for it is the
**small card** — `@CUECARD_SMALLCARD` and `@MENU_SMALLCARD`
(`Program/UIStrings.txt:732` and `:936`) — and this file is the catalogue
of every mark, badge, glyph, overlay, tint and letter one can show, what
each one MEANS, exactly when it appears and disappears, which code draws
it, and whether the art is **1997's own** or **ours**.

Each row names its picture. `01_plain.png` is the baseline: a card with
nothing on it.

---

## 1. The 1997 list, and how ours lines up against it

`@CUECARD_SMALLCARD` (`Program/UIStrings.txt:732-743`, latin-1 — GNU grep
prints **nothing** without `-a`; byte-identical in `../s30/assets/text/`
`Uistrings.txt:732-743`) declares **ten** states a small card can be
marked as, and those ten strings are the original's own vocabulary. This
is the comparison, in the table's own order:

| # | `@CUECARD_SMALLCARD` string | We draw it? | How, and where to look |
|---|---|---|---|
| 1 | `Damage to player` | **Yes — on the damage marker, not on a card** | `DamageMarker.CUE_PLAYER`. It is not a state of a permanent; it is a state of a *small card*, and the card it describes is a damage marker aimed at a player. `32_damage_marker_player.png` |
| 2 | `This card will untap` | **Yes** | `WillUntap.pic` -> `state_will_untap`, the blue curved arrow at the art's top-right. `15_state_will_untap.png` |
| 3 | `Damage: %d` | **Yes** | `Damage.pic` -> `damage_marker`, the red dagger at the art's bottom-right with the number beside it. `13_state_damage.png` |
| 4 | `Card is not controlled by owner` | **Yes, lettered** | The one state on the original's list with **no art in the 1997 set**, so it is written rather than invented: `stolen` on the status line. `16_state_not_owned.png` |
| 5 | `Is a target` | **Yes** | `Target.pic` -> `target_cursor`, the red crosshair over the art. `17_state_is_target.png` |
| 6 | `Can't target this` | **Yes** | `CantTarget.pic` -> `state_cant_target`, the orange circle-slash. `18_state_cant_target.png` |
| 7 | `Is a target, can't target again` | **Yes** | The same crosshair (`target_cursor`); only the cue card differs. `19_state_target_again.png` — **pixel-identical to `17`**, deliberately: one file, two meanings, exactly as the original imported it. |
| 8 | `Dying` | **Yes** | `Dying.pic` -> `state_dying`, silver cracks across the whole art. `14b_state_dying_alone.png` (and `14_state_dying.png` with the damage that caused it) |
| 9 | `Summoning sickness` | **Yes** | `Summon.pic` -> `summon_sick`, the grey spiral over the art. `12_state_summoning_sick.png` |
| 10 | `Phased` | **No — and it cannot be drawn today** | `MtgGame.phase_out` moves the instance out of `players[pid].battlefield` into `phased_out` while leaving `zone == BATTLEFIELD`; there is no `Mtg.Zone.PHASED_OUT` and no widget is ever built for a phased permanent, so nothing can ask the question. It becomes answerable the day the board draws phased-out cards. |

**Nine of the original's ten are drawn. One — `Phased` — is not, and the
reason is structural rather than cosmetic.**

Everything else in this catalogue is an ADDITION of ours (or of s30's),
and section 3 says which is which for each one.

---

## 2. Where things sit on the card

A quick map, in the card's own 132x106 coordinates, so a mark can be found
by eye. Z-order runs bottom to top: the spiral, the cracks, the corner
arrow, then the centre stamp — the transient targeting news, on top. The
mana stripes and the P/T carry an explicit `z_index` of 1 and the name and
the `(T)` a 2, so the lazily-added overlays cannot land over them.

```
 +--------------------------------------------------+
 | (T)  Card Name                        \ \ \ \ \ \ |  title bar (y 2..18)
 +--------------------------------------------------+  (T) left, stripes right
 | stolen                            [12]      /|\   |  status line / ID tag
 |                                              |    |  will-untap arrow (top-R)
 |                 THE ART WINDOW                    |  7.5%..92.5% x 19%..91.7%
 |            spiral / cracks / crosshair            |  the whole window
 |                                                   |
 |  (o)(o)(o)(o)                  |x 3               |  badges (bottom-L)
 |                                     6/4           |  dagger + number, then P/T
 +--------------------------------------------------+
```

The card is an eighth of the window wide in the original —
`set_smallcard_size` is `mainwindow_width / 8`
(`shandalar-src/src/functions/windows.c:1088`; the 1997 code it replaces
is a literal `sar eax, 3` at `Magic.exe:494d3c`) — which is why our
constants are RATIOS of `MiniCard.SIZE` rather than pixel counts.

---

## 3. The catalogue

### 3.1 The card body — what every small card wears

| Mark | Picture | What it means | When it appears / disappears | Drawn by | Art |
|---|---|---|---|---|---|
| **The frame** | `01_plain` | The card's colour identity: white / blue / black / red / green, gold for multicolour, grey for artifacts, brown-tan for lands (five land frames — one each for white, blue, black, red and green mana; a land that makes none, or that the mapping cannot place, falls back to the artifact frame). | Always. | `MiniCard._apply_style`, `frame_skin_key`, `FRAME_COLORS` | **1997** — `Cardbk_*.pic` -> `card_frame_*` (12 keys). Without the imported skin a flat `StyleBoxFlat` in the same identity colour stands in. |
| **The title bar** | `01_plain` | The card's name strip. With the skin it is the frame's own **top border** (the first 5.5% of `Cardbk_*.pic`), which is exactly how the original draws a card's row in a pile — *"each card represented by its top border"*. | Always (hidden on a face-down card). | `MiniCard.frame_strip`, `_build_face` | **1997** |
| **The name** | `02_name_white` / `03_name_yellow` | **White** = you cannot cast or use it now. **Yellow** = you can, right now — or the pointer is on its row. | `castable` or `hovered`. Pushed from `CardPile._make_card` (the stacked hand and the battlefield piles) and from `DuelScreen._make_card` (the fan, and every lone card on the table) — both off the same `_highlight_for` call, since 2026-09-04 (§5.5). | `MiniCard.name_color`, `_tint_face` | **Ours** (the rule is read off the owner's zoomed 1997 screenshot, where "Disenchant" reads lighter and gold under the pointer). |
| **The art** | `01_plain` | The card's picture, inset so the frame shows on all four sides. A land whose live basic subtype no longer matches its printed one draws THAT land's art instead (Blood Moon over a Strip Mine) — CR 305.7, and `Duel.hlp` **Territory** supports it from the other end with its *"**Original Type** shows you what this card was when it was cast"* menu entry. | Always. | `MiniCard.art_name`, `GameSkin.card_art` | Scryfall art crops (`tools/fetch_card_art.py`), not 1997. |
| **Power / toughness** | `01_plain`, `09_pt_pumped`, `10_pt_weakened` | The creature's **live** power and toughness, bottom-right, 25px white with a 4px black outline. **Green** when pumped above the printed values, **red** when weakened, **white** when unchanged. | Creatures only, and only while `Show power/toughness on small cards` is on (`Duel.hlp`, **Dueling Options**: *"...the current power and toughness of each creature is displayed on the card in play. (The Showcase always shows the original power and toughness.)"*). | `MiniCard.pt_color`, `refresh` | The pair is **1997**'s (the option exists to switch it off). The three-way colouring is **[s30]**, `duel.go:3402-3416` / `3780-3786`; the size is s30's measured ratio, `duel.go:1360-1364`. |
| **Mana stripes** | `06_stripe_one`, `07_stripe_two`, `07b_stripe_lotus` | One diagonal slash per colour the card can tap for. Every colour owns a **fixed slot** along the bar — W U B R G C, left to right, 9px apart — so a card that makes several shows several, each in its own place. Black Lotus wears all five. | Whenever the card has mana abilities. Dimmed under the tap wash when the card is tapped. | `MiniCard._rebuild_stripes`, `stripe_texture` | **1997** — `Manastripes.pic` -> `mana_stripes` (54x126 = six 54x21 cells). The importer records that the original drew this strip on a card's **hand row**; drawing it on the table card too is **ours**, because one widget serves both. |
| **The ID tag** | `08_id_tag` | The card's unique id for this duel, top-right of the art. *"...toggles the display of each card's unique ID code. This can be useful when you need to determine exactly which of several otherwise identical cards is the target of a specific spell or effect."* (`Duel.hlp`, **Territory**.) | Only while `Show ID tags` (Ctrl+T) is on — off by default. Shown even on a face-down card, which is the whole point of it. | `MiniCard.refresh`, `_id_tag` | **1997 feature** (`@MENU_TERRITORY` entry 18, `@MENU_SMALLCARD` entry 5, `UIStrings.txt:942`); the placement and the lettering are **ours**. |
| **Hover** | `04_hovered` | The pointer is on this card (or on its row in a pile). The whole widget lifts by a 1.25 multiply and the name turns yellow. | `hovered`. In a pile the row's holder pushes it down, because the card itself is mouse-transparent there. | `MiniCard._apply_modulate`, `CardPile._on_card_hover` | **Ours** (from the owner's 1997 screenshot). |
| **The card back** | `05_face_down` | A card whose face is hidden. No name, no art, no tooltip, no stripes, no state overlays — *a card back tells the table nothing about itself.* | `MiniCard.face_down`, carried from `CardInstance.face_down` by `DuelScreen._make_card`, `CardPile._make_card` and `GraveyardView._card` (2026-09-04, §5.1). An Illusionary Mask creature and a card exiled face down wear it, **to every seat**. It is still clickable on the battlefield: a face-down permanent attacks, blocks and is targeted. | `MiniCard._apply_face_down_style` | **1997** — `Cardback.pic` -> `card_back`. |

### 3.2 Tapped

`Duel.hlp`, topic **Tap**, verbatim: *"Tapping a card means turning it
sideways. This indicates to you and your opponent that the card effects
have been temporarily used up."* A tapped permanent wears **three** cues,
and they do different work at different distances.

| Mark | Picture | What it means | When | Drawn by | Art |
|---|---|---|---|---|---|
| **The 90° turn** | `11_tapped`, `34_pile_tapped` | Tapped. Clockwise, about the card's own centre, 0.22s ease-out — and RESUMED at the right angle across the board's rebuilds, so a card that has been tapped for a minute never spins again. Reads across the table. | `wants_rotation()`: on the battlefield, tapped, not face-down — **and** the parent has given the card a centre pivot (`MiniCard.aim_turn`). A fanned hand card is tilted by the fan instead and never turns. | `MiniCard.tap_turn`, `aim_turn`, `turn_holder`; `CardPile` turns its own rows | Both resting looks are **1997**'s. The sweep between them is **[QoL]** — no source we hold shows an in-between frame. |
| **The dark title bar** | `11_tapped` | The same thing, read **down a column of overlapping rows**: the bar's background is pale marble, so what the eye picks out in a stack of five is the two dark bars among the light ones. It also dims the mana stripes, which is the point — a tapped Mountain's red slash goes dull. | With the turn. `TAPPED_WASH = (0.02, 0.02, 0.04, 0.55)`. | `MiniCard._refresh_tap_mark`, `_tap_wash` | **Ours.** |
| **`(T)`** | `11_tapped` | The same thing again, read when the card is **half-covered and only its title bar shows**. Plain ASCII on purpose: `U+27F3 ⟳` is glyph 0 — missing — in all three fonts this widget can end up with, including `ThemeDB.fallback_font`, so the pretty glyph drew a tofu box. | With the turn. Takes 17px at the bar's left end; the name gives way by exactly that much so marked rows line up as a column. | `MiniCard.TAPPED_MARK`, `_tap_mark` | **Ours** (the owner asked for all three at once, 2026-09-04). |

### 3.3 The eight 1997 states a card can be in

These are `MiniCard.State` — eight of the ten in §1 (`Damage to player`
belongs to the damage marker, `Phased` cannot be asked). Each carries its
`@CUECARD_SMALLCARD` string **verbatim** as its tooltip, gated by
`Show cue cards` (`Duel.hlp`, **Dueling Options**: *"...the tiny hints that
pop up when you position the mouse cursor over an active location. If you
don't like the little tips, toggle the cue cards off."*).

| State | Picture | The mark | What it MEANS | Appears when | Disappears when | Art |
|---|---|---|---|---|---|---|
| `SUMMONING_SICK` | `12_state_summoning_sick` | A grey **spiral** over the whole art, at full strength. | The permanent has not been under your control since the start of your turn: it cannot attack and cannot pay a `{T}` cost. It CAN block. | On the battlefield, `summoning_sick`, without haste and without `cur_attacks_as_if_hasty` (Instill Energy lifts only the attack gate). **Creatures only**, unless `Show all cards' summoning sickness` (Ctrl+U) is on — the 1997 key is `ShowAllCardsSummonSickness`, i.e. *all cards*, and in this engine sickness reaches every permanent (CR 302.6; the original played the pre-Sixth rule where an artifact's `{T}` was sick too). | At the start of its controller's turn. | **1997** — `Summon.pic` (194x97: a 97x97 image beside its mask) |
| `DAMAGE` | `13_state_damage` | A red **dagger** at the art's bottom-right with the amount beside it in salmon. | How much damage is marked on this creature. When it reaches the creature's toughness the creature is destroyed. Note the P/T beside it still reads the LIVE 6/4 — damage in 1997 is a *marker*, not a subtraction (manual p.114), which is why we do not print s30's `power/(toughness-damage)`. | On the battlefield with `damage > 0`. | In the cleanup step, so a survivor soaks up its toughness again every turn. | **1997** — `Damage.pic` (84x26) |
| `DYING` | `14b_state_dying_alone`, `14_state_dying`, `30_death_mark` | Silver **cracks** spreading across the whole art. | The card is about to go to the graveyard — the one moment a regeneration effect can still answer for it. The original's own predicate is `kill_code == KILL_DESTROY` (`shandalar-src/src/functions/windows.c:724`, quoting the exe's string at `0x786f08`), the same predicate regeneration targets (`defs.h:2481`), refused with the line three cards carry: `Illegal target (not dying).` (`Program/prompts.txt:239`). `Duel.hlp`, **Regeneration**: *"You can use regeneration ONLY at the time when a creature is about to go to the graveyard."* | **Two ways.** (a) *Live*: on the battlefield, a creature, damage >= toughness, not indestructible — real only while the engine holds the moment open, which is the Fifth-Edition regeneration step. **See §4: that path is off by default.** (b) *Forced*: `force_dying` on the ghost inside a `DeathMark`, raised off `Mtg.EventType.DIES`. | (a) when the state-based check runs; (b) after `DeathMark.HOLD` + `FADE`. | **1997** — `Dying.pic` (194x97) |
| `WILL_UNTAP` | `15_state_will_untap` | A blue **curved arrow** at the art's top-right corner. | It is tapped and nothing is holding it down, so it comes back at its controller's next untap step. **Its ABSENCE on a tapped card is the news** — something (a Meekstone, a Paralyze) is keeping it that way. | Tapped, on the battlefield, with none of `skip_next_untap`, `skip_untaps`, `cur_skips_untap` — and, when the widget has a game to ask, only while `game.untap_caps` is empty (a Winter Orb or a Smoke caps how many untap at all, and while one is out this widget will not promise anything). | On untapping, or the moment a lock lands. | **1997** — `WillUntap.pic` (110x59 — the halves are NOT square) |
| `NOT_OWNED` | `16_state_not_owned` | The word **`stolen`** on the status line under the title bar. | Somebody has taken it — Control Magic, Steal Artifact — so it sits in a territory that is not its owner's. | `controller_id != owner_id` on the battlefield. | When control returns. | **No 1997 art exists** for this state — it is the one entry in `@CUECARD_SMALLCARD` the original ships no picture for, so it is **lettered rather than invented**. The word `stolen` is **ours**. |
| `IS_TARGET` | `17_state_is_target` | A red **crosshair**, 40x40 at the card's centre. | Something on the spell chain is aimed at this card. | Any live stack item names this instance (`game.stack` walked by id, the same walk `target_arrows.gd` does). Needs the optional `game` reference — a card in the Deck Builder or the help screen simply never draws it. | When that item resolves or is countered. | **1997** — `Target.pic` (122x61). **One file, two uses**: the duel screen's targeting *cursor* takes its raw image half, this takes the decoded sprite. |
| `CANT_TARGET` | `18_state_cant_target` | An orange **circle-slash** (a no-entry sign), same spot. | While you are choosing targets, the spell or ability in hand refuses this card — wrong colour, wrong type, protection, or a card that cannot be targeted at all. | Pushed down by the duel screen (`DuelScreen._target_state_for`), because it is a question about the *prompt in progress*, not about the card. Only for cards **on the battlefield** — stamping every land and every card in hand would be noise. | When the prompt ends. | **1997** — `CantTarget.pic` (130x65) |
| `TARGET_AGAIN` | `19_state_target_again` | The same red **crosshair** as `IS_TARGET`. | You have already picked this card for the slot you are filling; pick a different one. | Pushed down by the duel screen when the id is already in `_pending_groups[_pending_slot]`. | When the prompt ends. | **1997** — `Target.pic` again |

The three centre stamps share one spot and are **mutually exclusive**; the
order they win in is a refusal beats a re-pick beats a plain target
(`MiniCard.CENTRE_STAMPS`).

### 3.4 The frame highlights — "you may act on this"

The colour code is the **manual's**, not s30's. p.128: *"Mandatory effects
are highlighted in orange, while optional effects are in yellow."* And
p.115 / p.120 / p.126 use one word — *highlighted* — for every "you may act
on this" cue (a castable hand card, an attack-eligible creature, an
eligible blocker, a legal target, an activatable permanent), which is why
they all collapse into ONE optional state instead of s30's four separate
yellows and oranges.

| Highlight | Picture | Colour | What it means | Pushed by |
|---|---|---|---|---|
| `NONE` | `01_plain` | — | Nothing to do here. | default |
| `OPTIONAL` (= `CASTABLE`) | `20_highlight_optional` | Yellow `(0.95, 0.80, 0.25)` | **You MAY act on this**: an affordable spell or a playable land in hand, a permanent with an ability you can pay for, a mana source that can pay for the cast you are in the middle of. | `DuelScreen._highlight_for` |
| `MANDATORY` | `21_highlight_mandatory` | Orange `(0.95, 0.55, 0.10)` | **You MUST act on this**: a creature that must attack, an attacker that must be blocked (Lure). | `DuelScreen._highlight_for` |
| `COMMITTED` (= `SELECTED`) | `22_highlight_committed` | Green `(0.35, 0.85, 0.35)` | Already chosen and locked in: a pending attacker, an assigned blocker, a card picked for discard, a creature given combat damage. | `DuelScreen._highlight_for` |
| `TARGET_LEGAL` (= `TARGET`) | `23_highlight_target_legal` | Yellow, border width 2 | A legal target for the spell being aimed. | `DuelScreen._highlight_for`, `GraveyardView` |
| `TARGET_CHOSEN` | `24_highlight_target_chosen` | Green, border width **3** | A target you have already picked for it. The extra width is **[s30]**'s one width distinction (`duel.go:3302-3377`, block 5). | `DuelScreen._highlight_for` |

Green-for-committed is **[s30]**'s hue; the original leaves no evidence
either way.

The border **widths** are drawn twice over, because the two frames cannot
draw them the same way. On the **unskinned** frame they are the
`StyleBoxFlat`'s own border — `37_unskinned_none` (1px),
`38_unskinned_target_legal` (2px yellow), `39_unskinned_target_chosen`
(3px green). On the **skinned** frame the border belongs to a
`StyleBoxTexture`, which has no width at all, so since 2026-09-04 the
width is a RING drawn over the frame at the state's own
`HIGHLIGHT_WIDTH` (`MiniCard._highlight_ring`, the same device
`CardPile` rings a piled card with). It is built only when a highlight
asks for one, so a resting card renders byte-for-byte what it always did;
it is `MOUSE_FILTER_IGNORE`, so it takes no clicks. See §5.2 for the
defect it closed.

Note what is NOT a defect: `OPTIONAL` and `TARGET_LEGAL` share both a hue
AND a width, so `20` and `23` are identical pictures **on either frame**,
and always were. What tells those two apart is the crosshair, not the
border. The pair that carried real information — `COMMITTED` at 2 against
`TARGET_CHOSEN` at 3 — is the one the skin used to flatten.

### 3.5 The ability badges — the bottom-left row

`Duel.hlp`, **Dueling Options**, on `Show abilities on small cards`:
*"...(flying and such) are marked on the card by ability icons. If you want
to see these reminders, toggle this option on."* Badges are drawn only for
permanents **in play**, are 17px, run left to right along the bottom edge,
and are **clipped at the P/T box** — the numbers own that corner, because
they are the thing the owner asked to be readable across the table.

All of them come from one 1997 sheet: `Abilities.pic` -> `ability_icons`,
22x396 = **one column of 18 cells of 22x22**. Each cell is a disc on an
opaque black square, so it is masked to its inscribed circle before use
(measured: across all 18 cells the furthest non-black pixel sits at
r=11.068 and the nearest black one at r=11.34, so a cut at `cell * 0.51`
separates icon from backdrop with no judgement call).

| Badge | Cell | Picture | Meaning | Predicate |
|---|---|---|---|---|
| Activation cost | (mana sheet) | `29_badge_activation_cost`, `27_badge_regeneration` | This permanent has an ability you can pay to use, and this is the cost. One badge only — the Showcase lists them all. | first entry of `cur_activated_abilities`, drawn with `ManaIcons.cost_row` |
| Wing — **flying** | 11 | `25_badge_keywords` | | `cur_keywords` |
| Red foot — **trample** | 12 | `25_badge_keywords` | | `cur_keywords` |
| Blue cross — **banding** | 13 | `25_badge_keywords` | | `cur_keywords` |
| Sword-and-shield — **first strike** | 14 | `25_badge_keywords` | | `cur_keywords` |
| Pale star — **reach** | 16 | `25_badge_keywords` | 1997 called it **Web**; `Program/UIStrings.txt` carries the Manalink modernisation `Reach`. | `cur_keywords` |
| Green trident — **regenerates itself** | 15 | `27_badge_regeneration` | There is no `Mtg.Keyword.REGENERATION`: regeneration in this pool is an activated ability whose effect is a `RegenerateEffect`. The badge asks whether the shield is for THIS card (a target spec would mean it regenerates something else — Ragnar, Elephant Graveyard). | `MiniCard.regenerates_itself` |
| Coloured shields — **protection from a colour** | 5 G, 6 R, 7 U, 8 B, 9 W | `26_badge_protection` | | `cur_protection` bitmask |
| Brown shield — **protection from artifacts** | 10 | `28_badge_artifact_ward` | `cur_protection` is a colour bitmask with no room for a non-colour entry, so this is asked of the two live lists protection is actually made of: artifact damage prevented AND artifact sources barred from targeting. Artifact Ward is the only card in the pool that grants it. | `MiniCard.warded_from_artifacts` |
| **Cell 17 is blank** | 17 | — | 484/484 px of solid black, one unique colour, on both our import and s30's conversion. s30 maps Menace there (`duel.go:1047-1121`); the 1997 game had no menace keyword and no icon for it, so that mapping blits a black square. **Do not "complete" the map** — `test_menace_is_not_badged` pins it. | — |

The cell map is **[s30]**'s `keywordIconIndex`, verified against the
imported sheet at 4x. The art is **1997**'s.

### 3.6 Marks that ride ON or BESIDE a card

| Mark | Picture | What it means | When | Drawn by | Art |
|---|---|---|---|---|---|
| **The dying mark** | `30_death_mark` | A ghost of the destroyed card, wearing `Dying.pic`'s cracks, held over the square it has just been swept from. It is a whole card and not bare cracks on the felt, and that is a correctness choice: the board re-flows within a frame or two, so cracks alone would end up sitting on a LIVE neighbour and saying that IT was dying. | Raised off `Mtg.EventType.DIES` from inside the card itself — the widget hears its own death, because by the next `state_changed` there is no widget left. **A sacrificed permanent gets none** (1997's `KILL_SACRIFICE` is a different kill code and does not read `Dying`, which is also why regeneration cannot answer a sacrifice). A regenerated creature can never wear it. | `game/duel/death_mark.gd` | The cracks are **1997**. `HOLD = 0.45s` + `FADE = 0.55s` are **[QoL]**, ours — 1997's window lasts as long as the player takes to pass the regeneration step. |
| **The damage marker** | `31_damage_marker`, `32_damage_marker_player`, `33_damage_marker_refused` | One waiting damage packet, drawn as a card and clicked like one: the SOURCE on the title bar, the AMOUNT big over the middle, the VICTIM along the bottom. Manual p.119 calls it *"a damage marker — a yellow 'card' on or near the target of that damage"*; `Duel.hlp` names it three times as a thing you can target (*"click on any valid target — a card, **a damage marker**, or whatever"*, topics **Using Land**, **Spells**, **Effects**); and the original's own prompt for clicking one is `@CIRCLE_OF_PROTECTION` (`Program/prompts.txt:185`): **`Select damage card.`** | Only while a damage-prevention window holds packets. **See §4 — the default ruleset never opens one.** | `game/duel/damage_marker.gd`, `damage_marker_layer.gd` | The dagger is **1997** (`Damage.pic`); the yellow card is the manual's description, the layout ours. |
| **The refusal stamp on a marker** | `33_damage_marker_refused` | The same orange circle-slash a card wears, for the same reason: the open slot refuses this packet. | `DamageMarkerLayer` pushes `MiniCard.State.CANT_TARGET`. | `damage_marker.gd` | **1997** — `CantTarget.pic` |
| **The pile "actionable" ring** | `35_pile_glow` | A 2px ring in the highlight's colour round a piled card. A pile is where lands live, and while a cast is waiting for its mana the sources that can pay are the whole prompt. Off for hand piles — six affordable cards would be six rings and no information; the hand says it with the yellow name instead. | `CardPile.glow_actionable` (battlefield piles only), for `TARGET` / `SELECTED` / `OPTIONAL` / `MANDATORY`. | `game/duel/card_pile.gd:311-322` | **Ours** (the manual's *"highlighted"*, given a form). |
| **The graveyard-view target ring** | — (same look as `35_pile_glow`) | The same 2px ring, added as a real child of the card, on a legal target inside the graveyard / exile / ante overlay. An ILLEGAL card there gets no stamp at all. | `GraveyardView`, while the screen is in `Mode.TARGETING`. | `game/duel/graveyard_view.gd:395-419` | **Ours** (s30 draws the same outline, `duel.go:3699-3712`). |
| **The aura peek** | `36_aura_peek` | Each enchantment attached to a permanent is drawn as a WHOLE card stepping out behind it — up 18px and right 6px per attachment, furthest first, the host on top — so the title bar of every aura is readable and each one is separately hoverable and clickable. | Any attachment. | `DuelScreen.AURA_PEEK`, `_make_widget` | **Ours.** It replaced a `+N aura` chip that was written across the host's art (the forty-first pass). |
| **The spell-flight ghost** | — | While a spell is animating from hand to the table, its home slot holds the space with `modulate.a = 0` and a ghost `MiniCard` is tweened across the screen. | `SpellFlight.is_flying(inst.id)`. | `game/duel/spell_flight.gd` | **[s30]**'s `spellIsAnimating` skip. |
| **Target arrows** | — | Drawn BETWEEN cards, not on them: source to target, anchored on live `MiniCard` rects. | While the stack holds a targeted item. | `game/duel/target_arrows.gd` | — |
| **The combat window's sword / shield / bones** | — | Lane markers in the Combat window — **one per side, not per card**. A creature in a combat lane wears nothing but its `COMMITTED` highlight. | — | `game/duel/combat_window.gd:225-230` | **1997** (`Winbk_Attackbones` and friends) |
| **Deck Builder only: the "pile" plate and the copy-count disc** | — | A bottom-left plate naming the pile a card is in, and a 22px dark disc at the bottom-right with how many copies the deck holds. Both are real children of a `MiniCard`, and both exist only in the Deck Builder. | — | `game/deck_builder/card_area.gd:797-856` | The count disc is **[s30]**'s `drawCountOverlay`. |

### 3.7 What is deliberately NOT on a small card

* **The set icon / set letters.** They live on the **enlarged card** in the
  Showcase (`card_preview.gd:622-627`, the printed symbol slot at
  0.878/0.559..0.925/0.598 of the card), on the title screen's card-pool
  row (`SetBadges`), and on the Deck Builder's filter buttons — never on a
  small card. The 1997 sheet for them, `Cardsets.pic` -> `card_set_symbols`
  (330x15, five 66-wide slots: The Dark, Legends, Arabian Nights,
  Antiquities, Astral), is imported and used by those. Only five sets ever
  had a symbol; Unlimited, Fourth Edition and the promos are **lettered**
  instead, which is the printed truth rather than a gap.
* **Counters.** There is **no +1/+1 counter, charge counter or poison
  marking on any small card**. The 1997 set ships `Cardcounters.pic` and
  `Poison.pic` for exactly this, and neither is imported:
  `Cardcounters.pic` has no MANIFEST row at all, and `Poison.pic` was
  surveyed and rejected because s30's conversion is 42x26 with an
  **all-black right half** — a dead mask that decodes to a fully
  transparent sprite. Only Manalink's 60x30 rescale has a working mask, and
  whoever builds the poison counter takes that one. The counter cue cards
  exist and are unused (`@CUECARD_COUNTERS_ArmageddonClock`,
  `@CUECARD_COUNTERS_ManaBattery`, `UIStrings.txt:745-751`).
* **Rarity.** No such concept anywhere in `game/`.
* **The mana cost.** Shown only on the enlarged card in the Showcase — the
  small card carries the stripes instead.
* **An ante mark.** The ante is shown as full `CardPreview`s in the
  opening window; no table card is marked.

---

## 4. What you will NEVER see, and why

An honest catalogue says what a player cannot reach.

1. **`Phased`** — genuinely unreachable, as §1 says. A phased-out
   permanent is not in `players[pid].battlefield`, so no widget is ever
   built for it.

2. **The face-down small card** (`05_face_down.png`) — **reachable since
   2026-09-04.** It had no caller at all when this was written:
   `MiniCard.face_down` was set nowhere in `game/` except a test, which is
   what made §5.1 a bug as well as a gap. `DuelScreen._make_card`,
   `CardPile._make_card` and `GraveyardView._card` now carry
   `CardInstance.face_down` onto the widget, so an Illusionary Mask
   creature and a card exiled face down by Knowledge Vault both wear
   `Cardback.pic`. What is still drawn by other means: the opponent's
   hidden hand is a plain purple `ColorRect` in `CardPile`, and the
   library stack draws `card_back` itself as a `TextureRect`
   (`duel_screen.gd:7030`).

3. **`Dying` from the LIVE predicate** (a creature standing on the
   battlefield with lethal damage marked) — **off under the default
   ruleset.** It needs the engine to hold the moment open, and the only
   thing that does is the Fifth-Edition regeneration step, behind
   `RulesOptions.damage_prevention_window` (`fifth_value: true`, modern
   default **false**). Even with the fork on it auto-skips unless a seat
   asked for the window AND somebody holds a regeneration effect
   (`MtgGame._open_regeneration_window`). Under the modern default
   `MtgGame.destroy` decides and moves in one call, and no frame is ever
   drawn with the creature standing and doomed. What a default-ruleset
   player sees instead is the **`DeathMark`** — the same cracks, one step
   later, held for a beat. That divergence is deliberate: a mark hung on
   the damage would sit on creatures that go on to regenerate, and a mark
   that appears late is better than one that lies.

4. **The whole damage marker** — and with it `@CUECARD_SMALLCARD` entry 1,
   `Damage to player` — is behind the same fork. `DamageMarkerLayer` only
   ever holds packets waiting in a damage-prevention window, so **a duel
   under the default (modern) ruleset never shows one.** Play
   `--rules fifth`, or switch `Damage prevention step` on in Options, and
   they appear.

5. **`Highlight.CASTABLE` as a distinct look** — it is declared as an
   ALIAS of `OPTIONAL` (`CASTABLE = OPTIONAL`), so nothing can tell the two
   apart, and any test of the form `highlight == Highlight.CASTABLE` is
   really a test for `OPTIONAL`. Same for `TARGET`/`TARGET_LEGAL` and
   `SELECTED`/`COMMITTED`.

6. ~~**The border-width distinction between a legal and a chosen
   target** — invisible whenever the 1997 skin is imported.~~ **Fixed
   2026-09-04**, §5.2. And it was never a *legal*-against-*chosen*
   distinction: those two share a width. The pair it hid was COMMITTED
   against TARGET_CHOSEN.

---

## 5. Defects found while cataloguing

**Found by this pass, read-only on game code; all six FIXED on
2026-09-04** in the pass that follows it. Each entry keeps the finding as
it was written and adds what was done, because the finding is the part
that is hard to get back.

### 5.1 A face-down permanent was drawn FACE UP — **fixed**

**The finding.** `MtgGame.put_from_hand_face_down` (Illusionary Mask,
`cards/sets/2ed/illusionary_mask.gd:63`) puts a card onto the battlefield
with `CardInstance.face_down = true`. Nothing ever copied that onto the
WIDGET: `MiniCard.face_down` is a separate field that only a test set. So
a masked creature was drawn with its **name, its art, its oracle tooltip
and its printed mana stripes on show** — the information the card exists
to hide. (Its P/T did not leak: `recalculate` already blanks a face-down
permanent to a 2/2, CR 708.2.) The exile plate got it right
(`duel_screen.gd:4023` keeps its plate for a face-down exiled card) and
the log got it right (`:4134` prints `(face down)`); the table did not.

**The fix.** `w.face_down = inst.face_down` where the widget is built —
`DuelScreen._make_card` (every lone card on the table, the aura peek and
the Combat window, which share the builder) and `CardPile._make_card`
(the piles and the stacked hand). A third site the finding did not name
needed it too: `GraveyardView._card`, which is what opens over the exile
pile — the plate outside kept a Knowledge Vault card shut and the viewer
inside named it.

**WHO SEES A CARD BACK: every seat, the controller's included.** CR 708.2
lets a permanent's controller look at their own face-down permanent, so
the ideal answer is per-seat. **`engine/` cannot give one.** There is no
`may_look_at(pid, inst)`, no viewer on `MtgGame`, and
`CardInstance.face_down` is a single global bool that `recalculate()`
uses to blank the card's characteristics for everybody. The nearest thing
the UI holds is `DuelScreen.hidden_hands` (`config.hidden_seats()`),
which answers "may this viewer see that seat's hidden cards" — but it is
empty in hotseat and in an AI-vs-AI demo, so keying off it would draw
every masked creature face UP in those modes. So the table takes **the
reading that cannot leak**: a card back to everyone. The `Show ID tags`
overlay still draws on a face-down card, which is what tells two masked
creatures apart until the engine can answer properly.

**Two consequences worth knowing.** (a) `refresh()` used to `disabled =
true` every face-down widget; harmless while nothing set the flag, but a
masked creature must stay clickable — it attacks, it blocks, it is a
legal target — so only a face-down card that is NOT on the battlefield is
disabled now. (b) `MiniCard.wants_rotation()` still refuses to turn a
face-down card, so a masked attacker tapped in combat does not draw its
90° turn. Tappedness is PUBLIC information, so that is an omission in the
safe direction, and it is the one piece of §5.1 deliberately left open.

### 5.2 The skinned frame threw away `HIGHLIGHT_WIDTH` — **fixed**

**The finding.** `MiniCard._boxes_for` has two branches. The unskinned one
builds a `StyleBoxFlat` and applies both `HIGHLIGHT_COLORS` and
`HIGHLIGHT_WIDTH`. The skinned one builds a `StyleBoxTexture` and applies
**only** the colour, as `modulate_color`. Because `TARGET_LEGAL` shares
its hue with `OPTIONAL` and `TARGET_CHOSEN` shares its hue with
`COMMITTED`, the result with the 1997 skin imported was that
`20_highlight_optional.png` / `23_highlight_target_legal.png` and
`22_highlight_committed.png` / `24_highlight_target_chosen.png` were
**byte-identical pairs**.

**Read that evidence carefully, though.** `OPTIONAL` and `TARGET_LEGAL`
share a width as well as a hue (both 2), so `20`/`23` are identical on the
UNSKINNED frame too, by design — the crosshair is what tells them apart,
not the border. **The one pair that lost information was `22`/`24`**:
green at 2 against green at 3, which is s30's single width distinction
(`duel.go:3302-3377`, block 5).

**The fix.** A `StyleBoxTexture` has no border width, so the width is
drawn as a **ring over the frame** — `MiniCard._highlight_ring`, a
`Panel` at `PRESET_FULL_RECT` carrying a `StyleBoxFlat` in the state's own
`HIGHLIGHT_COLORS` at its own `HIGHLIGHT_WIDTH`. It is the same device
`CardPile` already rings a piled card with. Three properties are
load-bearing and pinned by tests: the node is built only when a highlight
asks for one (so `Highlight.NONE` costs nothing and renders identically);
it is `MOUSE_FILTER_IGNORE` (a `Panel` defaults to `STOP`, which would
swallow the press that taps the land under it); and it goes on the
TEXTURED frame only (the flat frame already draws its own widths, which
`37`/`38`/`39` pin).

**Proved by rendering, the way the defect was found.** Each highlight
rendered alone at one fixed spot on a skinned card and cropped at the
card's rect:

| pair | before | after |
|---|---|---|
| `committed` vs `target_chosen` | **byte-identical** | 1367 bytes differ |
| `optional` vs `target_legal` | byte-identical | byte-identical *(correct — same hue, same width)* |
| `none` before vs `none` after | — | **byte-identical** *(the resting card is untouched)* |

### 5.3 The help page documented a mark we removed — **fixed**

`game/help/help_pages.gd` taught a **`+N aura`** chip on the small card.
`MiniCard._refresh_status` deleted it in the forty-first pass (*"NO `+N
aura` CHIP HERE ANY MORE"*) when the aura fan replaced it. The help screen
is the one place a player goes to learn this vocabulary, and it was
describing a mark that no longer exists. The icon entry now teaches the
aura peek instead — a whole card stepping out from behind its host — and
`tests/ui/test_help_screen.gd` fails if the string `+N aura` reappears
anywhere in the help corpus.

### 5.4 `_tint_face`'s comment did not match its code — **fixed**

The comment said *"the name reads DARK on a light bar (white/tan cards)
and GOLD on a dark one (blue, red, black) — the reference's contrast
rule"*, but the code sets `_name_label`'s colour to `name_color()`
unconditionally — always white, or yellow when castable/hovered. Only
`_status_label` gets the light-bar/dark-bar treatment.

**The CODE is right and the words were wrong**, so the words changed. The
yellow/white pair is INFORMATION — can you cast this? — and it is the
original's own hand list; a name that went dark on a marble bar would be
saying "not castable" in the one place a player reads castability. What
keeps it legible on a pale bar is its 3px shadow outline, not a contrast
rule. The comment now states both rules and says which belongs to which
label; `tests/ui/test_mini_card.gd` pins the behaviour on a light bar and
a dark one, and greps the file for the old sentence.

### 5.5 The yellow "castable" name existed only in a pile — **fixed**

`MiniCard.castable` was assigned in exactly ONE place in the whole
codebase: `card_pile.gd:305`. `set_highlight` does not set it. So a card
in the **fanned** hand (Options -> *Hand display* -> "Fan of cards") never
yellowed its name however castable it was; only the **stacked list** — the
default, and the original's own style — routed through `CardPile` and got
it. The class doc and the help page both stated the rule unconditionally,
and since the double-click auto-cast landed the same yellow is also the
promise that double-clicking will work — so a fan player was denied the
promise as well as the cue.

`DuelScreen._make_card` now takes ONE `_highlight_for` call and uses both
halves of it: `w.castable = highlight == Highlight.CASTABLE` beside
`w.set_highlight(highlight)`. Same predicate as the pile's. That covers
the fan hand and every lone card on the table.

### 5.6 Card art moiréd at small-card size — **fixed**

Not a state, but it was in every picture here: the art is a ~582x467
Scryfall crop minified to ~110px with no mipmaps, which lays a regular
diamond lattice over any finely-detailed region (see the lion in
`01_plain.png`). Reproduced exactly by a nearest-neighbour downscale of
the source JPEG in PIL, so it is minification aliasing and nothing the
state code does.

Two lines: `Image.generate_mipmaps()` in `GameSkin.card_art` before the
`ImageTexture` is built, and
`texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS` on
`MiniCard._art`. No re-import, no texture-format change, no `.import`
file touched — this path bypasses Godot's import pipeline entirely.

**What it costs:** measured across all 897 art crops, **+33.2%**, i.e.
**+0.25 MB per art actually drawn**. A duel with fifty distinct cards on
screen pays about 12 MB. The filter is set on the SMALL CARD only, so the
Showcase and every other user of the same texture still draws from mip 0
and looks exactly as it did. The real memory risk on this path is
unchanged and pre-existing: `GameSkin._texture_cache` is a static
dictionary that never evicts, so a full browse of the Deck Builder's grid
would hold every art it has ever shown (682 MB across the whole pool
before this change, 909 MB after). That cache, not the mipmaps, is what
wants a bound.

---

## 6. The pictures

`../shandalar-build/shots/card_states/` — outside this repo, because they
are build output.

**They were taken BEFORE §5's fixes and three of them are now stale**:
`01_plain` (and every other picture) still carries the moiré §5.6
removed; `22`/`24` are still the identical pair §5.2 separated; and
`05_face_down` was a probe-only picture then and is a thing the game can
actually put on the table now. Re-shoot the set the next time this file
is revised.

`00_contact_sheet.png` is the whole catalogue on one page, grouped and
captioned. The rest are one state each, tightly cropped:

```
01_plain                  02_name_white             03_name_yellow
04_hovered                05_face_down              06_stripe_one
07_stripe_two             07b_stripe_lotus          08_id_tag
09_pt_pumped              10_pt_weakened            11_tapped
12_state_summoning_sick   13_state_damage           14_state_dying
14b_state_dying_alone     15_state_will_untap       16_state_not_owned
17_state_is_target        18_state_cant_target      19_state_target_again
20_highlight_optional     21_highlight_mandatory    22_highlight_committed
23_highlight_target_legal 24_highlight_target_chosen
25_badge_keywords         26_badge_protection       27_badge_regeneration
28_badge_artifact_ward    29_badge_activation_cost  30_death_mark
31_damage_marker          32_damage_marker_player   33_damage_marker_refused
34_pile_tapped            35_pile_glow              36_aura_peek
37_unskinned_none         38_unskinned_target_legal 39_unskinned_target_chosen
```

They were taken with a throwaway probe under `xvfb-run`, which built real
`MiniCard`s against a real `MtgGame` and cropped the live viewport; the
probe was deleted afterwards, as `CONTRIBUTING.md` requires. `manifest.json`
beside them carries each file's caption.

---

## 7. The 1997 art, by skin key

Everything in the table below is imported by `tools/import_original.py`
from the player's own copy — **original art never enters this repository**
(`Provenance.md`). Sizes are what a correct import produces; the numbers
are the **s30 `.pic.png` conversions**, and a Manalink install's
`Program/CardArt/` copies are visibly larger rescales of the same drawings
(Summon/Dying 254x127, CantTarget/Target 206x103, WillUntap 152x76) with
two-tone silhouette masks instead of real alpha. Both decode; the
conversion is preferred.

| Skin key | 1997 file | Size | Used for |
|---|---|---|---|
| `summon_sick` | `Summon.pic` | 194x97 | the sickness spiral |
| `damage_marker` | `Damage.pic` | 84x26 | the damage dagger, on a card and on a marker |
| `state_dying` | `Dying.pic` | 194x97 | the dying cracks |
| `state_will_untap` | `WillUntap.pic` | 110x59 | the untap arrow |
| `state_cant_target` | `CantTarget.pic` | 130x65 | the refusal circle-slash |
| `target_cursor` | `Target.pic` | 122x61 | the crosshair AND the duel screen's targeting cursor — one file, two uses, imported once |
| `ability_icons` | `Abilities.pic` | 22x396 | all 18 badge cells |
| `mana_stripes` | `Manastripes.pic` | 54x126 | the six colour slashes |
| `card_frame_*` (12) | `Cardbk_*.pic` | 228x325 | the frames and their title-bar strips |
| `card_back` | `Cardback.pic` | 228x323 | the face-down card |
| `card_set_symbols` | `Cardsets.pic` | 330x15 | the set symbols — on the ENLARGED card, not here |

Each of the five state files is an **image half beside a mask half**, and
the mask's polarity is not constant across the 1997 set — `Damage.pic`
masks its background white while the Combat window's sword and shield mask
theirs black. `MiniCard.masked_sprite` therefore MEASURES the polarity
from the mask's own top-left pixel (which is background by construction)
rather than carrying a per-file table.

`Poison.pic` and `Cardcounters.pic` are the two card overlays the original
ships that we do not import; see §3.7.
