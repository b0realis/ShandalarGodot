# Bug-hunt campaign — the whole game, 2026-10-07

The owner, after Pack 9: *"Ok now do another bug hunt campaign and later bug
fix campaign. This will be it for some time regarding card packs. Lets make
the whole game play smoothly and correctly and with good AI player."*

Seven read-only hunters covered the whole game by area — the core card pool;
packs 2–5; the cross-pack interactions of packs 6–9; the engine core; the
human duel screen; the AI's quality and stability over 1,400 seeded AI duels
(timed, every decision checked for self-harm); the network, the agent seat
and persistence. Every finding was reproduced by a probe that failed on it:
**84 findings (11 high, 47 medium, 26 low)**; a few were the same defect seen
from two sides (the Blinking Spirit removal, the 1997 prevention step's
hidden-hand leak, the "while tapped" artifacts). Nine fixers then worked
test-first on disjoint files — engine, cards, mana planner, three AI
owners, duel screen, network and agent seat, persistence — each turning its
probes into permanent regression tests, with the lead relaying the handovers
between them in a second wave.

New regression scripts (35 GUT, 1 Python):
`tests/unit/test_campaign_fix_engine_tapped_artifacts.gd`,
`tests/unit/test_campaign_fix_engine_damage_window.gd`,
`tests/unit/test_campaign_fix_engine_journal_apnap.gd`,
`tests/unit/test_campaign_fix_engine_band_blocks.gd`,
`tests/unit/test_campaign_fix_engine_announcement.gd`,
`tests/unit/test_campaign_fix_cards_object_matching.gd`,
`tests/cards/test_campaign_fix_cards_core.gd`,
`tests/cards/test_campaign_fix_cards_packs.gd`,
`tests/unit/test_campaign_fix_mana_planner.gd`,
`tests/ai/test_campaign_fix_mana_ai.gd`,
`tests/ui/test_campaign_fix_mana_autocast.gd`,
`tests/ai/test_campaign_fix_ai_a_burn.gd`,
`tests/ai/test_campaign_fix_ai_a_arrivals.gd`,
`tests/ai/test_campaign_fix_ai_a_removal.gd`,
`tests/ai/test_campaign_fix_ai_a_costs.gd`,
`tests/ai/test_campaign_fix_ai_a_asks.gd`,
`tests/ai/test_campaign_fix_ai_b_licid_budget.gd`,
`tests/ai/test_campaign_fix_ai_b_symmetric_statics.gd`,
`tests/ai/test_campaign_fix_ai_b_provider.gd`,
`tests/ai/test_campaign_fix_ai_b_card_flow.gd`,
`tests/ai/test_campaign_fix_ai_c_mistakes.gd`,
`tests/ai/test_campaign_fix_ai_c_casting.gd`,
`tests/ai/test_campaign_fix_ai_c_combat.gd`,
`tests/ai/test_campaign_fix_ai_c_engines.gd`,
`tests/ui/test_campaign_fix_ui_auto_pass.gd`,
`tests/ui/test_campaign_fix_ui_casting.gd`,
`tests/ui/test_campaign_fix_ui_net_specials.gd`,
`tests/ui/test_campaign_fix_ui_announcement.gd`,
`tests/tools/test_campaign_fix_net_referee.gd`,
`tests/ui/test_campaign_fix_net_table.gd`,
`tests/ui/test_campaign_fix_net_lobby.gd`,
`tools/test_campaign_fix_net.py`,
`tests/ui/test_campaign_fix_persist_pack_requirements.gd`,
`tests/ui/test_campaign_fix_persist_window_close.gd`,
`tests/unit/test_campaign_fix_persist_deck_store.gd`,
`tests/ui/test_campaign_fix_persist_draft_pool.gd`.

## The worst of what was found

- **Endless extra turns under the 1997 rules.** The fifth-edition rule
  "a tapped artifact's continuous effects stop" also switched off Time
  Vault's, Basalt Monolith's and Mana Vault's own "doesn't untap during your
  untap step", so they untapped for free: a human could take an extra turn
  every turn, and the Monolith and the Vault were free mana every turn. The
  same rule switched off the very bonus of Zelyon Sword, Spirit Shield and
  Tawnos's Weaponry ("for as long as this remains tapped"). A static can
  now be marked `working_while_tapped()`; the suspension skips it, and a
  census test finds every artifact whose Oracle text bans its own untap.
- **A blocked band came unblocked.** When the band member a creature had
  blocked left combat — bounced, or phased out by Pack 8's Reality Ripple —
  its partners were treated as unblocked and hit the player, and the
  blocker survived (CR 702.22h, 506.4). Blocking one member now blocks the
  band, and a departing member hands the blocker to the rest.
- **Holding Firestorm froze the host.** The check that every paid object is
  a different card (Firestorm's discards, Haunting Misery, Infernal
  Harvest) tried every ordering of the hand: 2.3 s at nine cards, minutes
  at eleven — on every view a network referee sent. It is a bipartite
  matching now (under 100 ms with fourteen cards).
- **Mana burn by the AI's own payment.** The shared mana planner paid a
  {1} with a Sol Ring, a Mana Vault or a Black Lotus while a basic land
  stood untapped, and tapped a land per pip under Mana Flare: 392 points of
  self-inflicted burn in 300 tournament-deck duels, and the human's
  double-click auto-cast did the same. It now pays with the least left
  over, sorts the costly sources last, stops tapping once the pool covers
  the bill, and plans for described bonus mana.
- **The duel screen stopped on every step** while the player held any
  untapped creature with an activated ability (Prodigal Sorcerer, a Shivan
  Dragon with a land open): the auto-pass priced abilities against all
  mana, not the floating pool. Nine cards could not be used at all because
  the screen asked the caster for a target the opponent or chance chooses
  (Orcish Catapult, Cuombajj Witches…).
- **A brief disconnect conceded the agent's seat** at a LAN table: every
  answer during the reconnect was counted as a refusal, and twenty
  refusals concede.

## Rules fixes

- **The 1997 damage-prevention and regeneration steps** open on public
  information only — a step-kind ability on the battlefield, a paid
  prevention shield, or any card in a hand — so whether a step opens no
  longer tells the other player what is in a hand. Each player passes on
  their own information (the duel screen and the AI pass at once with
  nothing usable). When both pass, only what was cast inside the step
  resolves in it; a spell already on the stack waits. A regeneration step
  that follows a prevention step starts with the active player.
- **Paying with City of Brass** (Kudzu, Manabarbs, Psychic Venom): a
  trigger raised by the caster's own mana abilities while paying an
  announced spell or ability no longer makes the cast illegal; it goes on
  the stack above the object once it is cast (CR 601.2g–h, 603.3) —
  `MtgGame.begin_announcement` / `end_announcement`, used by the duel
  screen, SGManalink and the AI's main-phase cast.
- **Smaller:** a {T} activation recalculates at once (Castle's bonus, a
  creature with lethal damage); graveyard triggers are stacked in APNAP
  order with battlefield ones (CR 603.3b); the search journal restores a
  game's end and the damage steps; a newer Humility removes menace granted
  by Imposing Visage or Goblin War Drums.
- **Cards:** Vesuvan Doppelganger's upkeep copy targets; Drain Power asks
  which mana ability each land uses; Fellwar Stone reads what a land could
  produce (Gem Bazaar's chosen colour); Deep Spawn is not asked about once
  it has left; Lim-Dûl's Vault reveals each look to its caster and asks
  whether to dig again; Icy Prison's "unless any player pays" is answered
  per player.

## The AI

Every policy change sits behind the existing `forecasts_tactics` gate with a
gate-off arm and a hidden-information permutation in its test.

- **Burn:** burn that is lethal only together is summed under one mana plan
  and fired at the face; an instant that would be discarded at cleanup is
  cast first; discards rank by castability.
- **Self-harm gone:** creatures whose mandatory "when this enters, target…"
  could hit only its own board (Fire Imp, Nekrataal, Oubliette, Man-o'-War's
  self-bounce loop); removal at a creature that escapes for free (Blinking
  Spirit — every fizzle in 256 Lab games) or that its controller can still
  regenerate; a second removal at an attacker already answered on the
  stack; Wicked Reward sacrificing its own target; Cone of Flame, Humility,
  Dread of Night, Light of Day and Choke cast into its own board (a
  speculative board projection); a creature cast before its own Wrath;
  decking itself (Braingeyser, Deep Spawn); a Dark Ritual with nothing
  useful to cast; Drop of Honey on its own creature; Animate Artifact on a
  Mox; a second Stasis or Pestilence; Time Elemental blocking a 1/1;
  Varchild's War-Riders' upkeep paid to arm the opponent; the Echo Chamber
  copy of a Phyrexian Dreadnought fed two Craw Wurms.
- **Used now:** Fireblast and Spinning Darkness as combat answers;
  first-strike pumps (Knight of Stromgald, the Orders); Necropotence past
  a flat five-life floor; Demonic Consultation names a real spell.
- **Fifth Edition reprints:** the Ice Age and Fallen Empires readings were
  gated on the displayed set code and skipped whenever Pack 7 or the Mirage
  block provided the card (21 names: Necropotence, Hecatomb, the Blasts…);
  they read `CardData.script_set` now.
- **The Apprentice's mistakes** keep their rates, but a fumble is never
  taken with mana already floating (419 points of Apprentice burn in 400
  fifth-rules duels), never drops a lethal line, never drops the block it
  needs to live; the roll is still made, so a seeded duel replays.
- **Speed:** with six or seven licids on the board one Wizard decision took
  up to 9.7 s; one plan per decision, the hosts that can matter and a shared
  node budget bring it to 1.3 s with identical decisions on the replayed
  duel. The Twist of Fire deck's zero-swing wheel loop (3,498 actions in 17
  turns) is refused; the deck now wins.

## The duel screen, the network and the agent seat

- **Duel screen:** the auto-pass prices abilities against floating mana; a
  card lights only when something can be aimed at and non-mana costs are
  payable; a no-target spell is refused before anything is tapped; a
  "mana value X" target is judged at the pending X; a tutor can fail to
  find; a cast finished during the opponent's priority waits for yours;
  "any player may activate" abilities on the opponent's permanents work;
  Abandon Hope's X is capped by the cards it can discard; when nothing can
  block, the empty block is declared for the player (a Stop on the blockers
  icon keeps the old stop).
- **SGManalink protocol 29** (`RULES_REVISION`
  `sgmanalink-campaign-2026-10-07`): a choice carries a card handle per
  line, so two Grizzly Bears can be told apart; a payable Sabertooth Cobra
  ransom or paid prevention stops the network screen and sits on its menus;
  unpayable special actions are not offered; no land is offered inside the
  1997 damage step; a tournament's return to the hall survives a blinking
  connection.
- **The agent seat:** the referee waits through a reconnect (the host's
  five-minute grace); the decision-menu driver never concedes for the
  model; a kept game's `referee_stop` is not lost; `--table NAME` joins
  that table; an unseeded duel reports its drawn seed only in the result
  (it dealt the opponent's hidden hand to a replay); `until` stops in the
  1997 damage steps; Magnetic Web's attack companions, Circling Vultures'
  discard and shadow reach the agent.
- **Persistence:** closing the window in the Deck Builder — or from the
  Booster Draft setup, or during a draft started from the builder — asks to
  save unsaved decks; a saved deck no longer keeps a pack requirement after
  its last card from that pack is gone; titles in other alphabets or with
  accents get their own file; a linked decks folder is the player's own;
  the Booster Draft setup answers at once, and its count arrows work.

## Left open

- **Illusionary Mask** reads "mana you spent on {X}" as mana value ≤ X; the
  colours are not checked (`docs/simplified-cards.md`).
- A deck saved with a stale pack requirement before this campaign still
  shows "(needs Pack N)" at battle setup until it is opened and saved once
  in the Deck Builder.
- The announcement bracket covers the AI's main-phase cast; its activations
  and instant-speed responses still hold a tap-trigger cast and retry it.
- A colour-choice mana source is never swapped for another colour when the
  planner prunes surplus (a Gauntlet-of-Might Mountain beside a Sol Ring
  for {1}{R}); Winter's Night carries no bonus descriptor (the run-time
  stop covers its burn).
- **Ruled by the owner after the campaign:** the Deck Lab's default rules
  preset was `modern` (no mana burn) while a player's default is
  `modern_mana_burn`, so Lab measurements hid mana-burn mistakes. The Lab
  now defaults to the player's preset (`DeckLab/README.md`, "The rules
  default"); a baseline taken before is reproduced with `--rules modern`.
- Unconfirmed by any probe, so not changed: a damage source's colour after
  it has left play is read as printed; cards drawn into the opening hand
  count as "drawn this turn" on turn 1; Su-Chi's death mana in combat.

## Verification

- Every probe failed before its fix and passes after it (two probes pin
  behaviour the fixes made obsolete: the Apprentice's tap-trigger hold, now
  replaced by the announcement bracket, and a hotseat asking the second
  seat for the Witches' target, which is correct); the probes
  (`tests/_hunt/`, never tracked) were then deleted.
- **Gate** (`SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh`): 793 scripts,
  **12,834 tests, 569,052 asserts**, every shard exit 0 — the 35 new
  regression scripts above and the adapted pins on top of 0.50.15's 758 /
  12,410.
- Python: 627 tests OK (15 skipped), `tools/test_tracked_tree.py` included.
