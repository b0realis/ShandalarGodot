class_name MtgGame
extends RefCounted
## The duel: two players, the turn structure, the stack, priority, combat,
## and — crucially — EVERY rule-relevant mutation of game state.
##
## Design contract (the most important sentence in the engine):
## [b]All game-state changes go through this class.[/b] Effects, abilities
## and card files never touch zones, life totals or characteristics
## directly; they call the mutation helpers here (deal_damage, draw_cards,
## destroy, ...). That single rule is what keeps the engine auditable,
## loggable, and later network/replay-able.
##
## How a UI, an AI, or a test drives a game — the public API:
##   setup(...)              build players and decks
##   start()                 begin turn 1
##   play_land / tap_for_mana / cast_spell / activate_ability
##   declare_attackers / declare_blockers
##   pass_priority           advances resolution and, eventually, the turn
## The engine is fully synchronous: each call completes all its
## consequences (triggers, state-based actions, step advancement) before
## returning. Signals mirror everything for presentation layers; a headless
## test needs none of them.
##
## Error handling: action methods return String — "" on success, else a
## human-readable refusal ("can only cast sorceries in your main phase").
## UIs show refusals verbatim; tests assert on them. Nothing throws.
##
## Scope notes (the full list is docs/ROADMAP.md; card-scoped deviations are
## docs/simplified-cards.md, and docs/mechanics.md catalogues what IS
## implemented): no priority in the cleanup step, the end-step and
## end-of-combat pools are turn-based actions rather than stacked delayed
## triggers (the ones that must outlive their source use [member
## delayed_triggers], which are real ones), and the CR 613 layer passes
## have no dependency analysis. Every one of them is
## marked SIMPLIFIED: inline at the exact spot a future implementation
## replaces. Ante, first strike, regeneration, protection, banding, phasing,
## poison, copying and multi-blocker combat all DO exist — this comment used
## to say otherwise, which is why it now names the docs instead.

# ------------------------------------------------------------------ signals --
# Presentation hooks. The engine never depends on anyone listening.

## A game event happened (also offered to triggered abilities).
signal event_occurred(event: GameEvent)
## A seat was asked a MID-RESOLUTION question and it has been answered —
## by the player if [member PlayerChoice.answered_by_player], otherwise by
## a heuristic on their behalf (docs/duel-todo.md §1.3).
signal choice_requested(choice: PlayerChoice)
## A line was added to the game log.
signal log_appended(line: String)
## Some state changed; UIs should refresh. Coarse by design.
signal state_changed
## The game ended. winner_id is 0 or 1.
signal game_ended(winner_id: int)

## The key in a combat-damage split that means THE DEFENDING PLAYER rather
## than a creature — trample's spill-over (CR 702.19b). No instance ever
## has id -1, so a split is a plain {id: points} dictionary either way.
const DAMAGE_TO_PLAYER := -1

# -------------------------------------------------------------------- state --

var players: Array[MtgPlayer] = []
var stack: Array[StackItem] = []

## One DecisionAgent per seat for mid-resolution choices (see that class).
## setup() fills these with defaults; set_agent replaces one (the AI does).
var agents: Array[DecisionAgent] = []
var continuous := ContinuousEffects.new()
var combat := CombatState.new()

## THE RULES FORKS — where the 1997 ruleset (which the original enforced,
## manual p.108) and modern Magic disagree. Each is a switch, defaulting
## to the modern answer; the Options screen drives them and the duel
## screen hands them here. See RulesOptions for the full table.
var rules := RulesOptions.new()

## Deterministic randomness: every shuffle/coin flip uses this RNG, so a
## seed reproduces a game exactly (vital for bug reports and AI training).
var rng := RandomNumberGenerator.new()

var turn_number := 0
var active_player := 0
## Index into Mtg.STEP_ORDER; see [method current_step].
var _step_index := 0
var priority_player := 0
var _passes := 0

## Combat flow gates: when true, the named declaration must happen before
## priority actions are accepted.
var awaiting_attackers := false
var awaiting_blockers := false

## THE DISCARD PHASE (docs/duel-todo.md §1.1). True while the cleanup step
## is held open waiting for the active player to choose which cards to
## discard down to their maximum hand size. Only ever set for a seat whose
## agent asked to be consulted ([method DecisionAgent.wants_to_choose_discard]);
## every other seat's agent answers and the turn never stops.
## Cleared by [method discard_to_hand_size], which then finishes cleanup.
var awaiting_discard := false

## How many cards [member awaiting_discard] is waiting for. 0 when it isn't.
var discard_count := 0

## COMBAT DAMAGE ASSIGNMENT (docs/duel-todo.md §1.4, §6.9). True while a
## combat damage step is held open waiting for one seat to divide one
## attacker's (or blocker's) damage — the original's
## `%s: Assign damage to blockers, %d points left` loop. Only ever set for
## a seat whose agent asked to be consulted
## ([method DecisionAgent.wants_to_assign_combat_damage]).
## [method damage_assignment_request] says what it is waiting for;
## [method assign_combat_damage] answers it.
var awaiting_damage_assignment := false

var game_over := false
var winner := -1

## True when the game ended in a DRAW rather than a win (CR 104.4 —
## Divine Intervention). [member winner] stays -1 in that case.
var is_draw := false

## Extra turns queued by Time Walk-style effects: player ids, taken in
## order before the turn passes normally (CR 500.7).
var extra_turns: Array[int] = []

## Fog: all combat damage this turn is prevented. Cleared at cleanup.
var combat_damage_prevented := false

## THE DAMAGE-PREVENTION WINDOW's queue (docs/duel-todo.md §6.8): the
## [DamagePacket]s that have been PLANNED but not yet landed, which is
## what the players get to point a prevention effect at. Empty except
## while a window is open, so nothing reads it in a duel played under the
## modern default (`RulesOptions.damage_prevention_window`).
var damage_pending: Array[DamagePacket] = []

## Caps on how many permanents of a kind a player may UNTAP during their
## untap step (Smoke, Winter Orb, Damping Field): keys "creature",
## "land", "artifact" -> maximum. Absent = no cap. Rebuilt from scratch
## by the continuous pipeline on every recalculation (statics write it
## through [method cap_untaps]). WHICH permanents untap under a cap is the
## controller's choice, asked in the untap step ([method _untap_step]).
var untap_caps: Dictionary = {}
## Which card set each cap — the name the untap step's "Select creature to
## untap." question wears (see [method cap_untaps]).
var untap_cap_sources: Dictionary = {}


## Cap how many permanents of [param kind] ("creature" / "land" /
## "artifact") each player untaps in their untap step (Smoke, Winter Orb,
## Damping Field). Called from a static on every recalculation; the
## tightest cap wins when two locks name the same kind.
func cap_untaps(kind: String, cap: int, source: CardInstance) -> void:
	var current: int = int(untap_caps.get(kind, -1))
	if current >= 0 and current <= cap:
		return
	untap_caps[kind] = cap
	untap_cap_sources[kind] = source.data.card_name

## Player ids allowed to play ANY number of lands this turn (Fastbond).
## Rebuilt from scratch every recalculation.
var unlimited_land_plays: Dictionary = {}

## Instance ids condemned to be destroyed at the beginning of the next
## end step (Berserk's attacker, Stone Giant's flier). Processed and
## cleared when the END step begins.
var _end_step_doom: Array[int] = []

## The subset of [member _end_step_doom] whose destruction only happens if
## the creature ATTACKED this turn (Berserk). Instance id -> true.
var _end_step_doom_if_attacked: Dictionary = {}

## The mirror clause: "destroy it at the beginning of the next end step if
## it DIDN'T attack this turn" (Nettling Imp).
var _end_step_doom_unless_attacked: Dictionary = {}

## The subset of [member _end_step_doom] that is SACRIFICED rather than
## destroyed at the end step (Dragon Whelp's fourth breath). A sacrifice
## can't be regenerated and ignores indestructible (CR 701.17).
var _end_step_doom_sacrifice: Dictionary = {}

## Tokens queued to be created at the beginning of the next end step
## (Rukh Egg's bird), as {controller: int, data: CardData}.
var _end_step_tokens: Array = []

## DELAYED TRIGGERED ABILITIES (CR 603.7) — "at the beginning of your next
## upkeep, ...", created by a resolving spell or ability and living on the
## GAME rather than on the object that made them, so they survive that
## object leaving (CR 603.7a: Hazezon Tamar exiled in response still
## raises his sandstorm; Nafs Asp's debt outlives the Asp). Each entry is
## {id, trigger: TriggeredAbility, controller, source: CardInstance,
## repeats, memory: Dictionary, desc, settle_cost: ManaCost, settle_by} —
## see [method schedule_delayed_trigger]. Fired by [method dispatch_event]
## in APNAP order with the battlefield's triggers; a once-only entry
## leaves the queue as it triggers (CR 603.7c), a repeating one ("at the
## beginning of each of your upkeeps for the rest of the game") stays.
var delayed_triggers: Array[Dictionary] = []
var _next_delayed_id: int = 1

## Caps on how many creatures may be declared as attackers / blockers
## this combat (Caverns of Despair). 0 = no limit. Rebuilt from scratch
## by the continuous pipeline on every recalculation, so a static that
## imposes the cap can come and go.
var max_attackers: int = 0
var max_blockers: int = 0

## Land subtypes whose landwalk is currently NULLIFIED — "creatures with
## <X>walk can be blocked as though they didn't have <X>walk" (Undertow,
## Deadfall, Great Wall, Quagmire, Crevasse, Gosta Dirk, Ur-Drago, Lord
## Magnus). Rebuilt from scratch by the continuous pipeline on every
## recalculation; consulted by CombatState.block_illegality. Kept OUT of
## cur_landwalk because the printed effect changes the blocking rules,
## not the creature's abilities.
var nullified_landwalk: Dictionary = {}

## Instance ids condemned to die when this combat ends ("destroy that
## creature at end of combat" — Cockatrice, Thicket Basilisk, Venom).
## Processed and cleared on entering the end-of-combat step; regeneration
## applies (it is a destruction).
var _end_of_combat_doom: Array[int] = []

## Control changes that end at cleanup ("gain control of that creature
## until end of turn" — Disharmony). Entries are {instance_id, owner_pid}.
var _control_until_eot: Array[Dictionary] = []

## "Creatures can't attack this turn" (Festival). Checked by
## declare_attackers, cleared at cleanup.
var no_attacks_this_turn: bool = false

## Player ids for whom "attacking doesn't cause creatures you control to
## tap this combat" (Johan). Set by a card, read by
## [method declare_attackers], cleared when the combat phase ends — the same
## moment the until-end-of-combat effects expire (CR 700.5).
var attacks_without_tapping: Dictionary = {}

## "Instead of declaring blockers, blocks are assigned at random this turn"
## (Camouflage). Set by the spell, honoured by declare_blockers, cleared at
## cleanup.
var camouflage_this_turn: bool = false

## DELAYED end-of-combat ACTIONS (Glyph of Doom's "at this turn's next end
## of combat, destroy all creatures that were blocked by that creature this
## turn"). Each entry is a Callable(game: MtgGame) -> void, run once when
## the end-of-combat step begins and then dropped. Independent of any
## permanent — the effect that scheduled it may be long gone (CR 603.7a).
var _end_of_combat_actions: Array[Callable] = []

## Delayed actions to run at the beginning of the next END STEP — the
## end-step twin of [member _end_of_combat_actions]. Rakalite.
var _end_step_actions: Array[Callable] = []

## Delayed actions to run at the beginning of one player's NEXT main phase.
## Each entry is {"player": int, "action": Callable}. Mana Drain's "at the
## beginning of your next main phase, add {C} equal to that spell's mana
## value" is the pool's only user.
var _next_main_actions: Array[Dictionary] = []

## "Whenever <that creature> is dealt damage this turn, you gain that much
## life" (Glyph of Life). Entries are {instance_id: int, controller: int,
## attackers_only: bool}; MtgGame.deal_damage pays them out. Cleared at
## cleanup — the watch is for this turn only.
var life_on_damage_watchers: Array[Dictionary] = []

## How much damage each SOURCE has dealt this turn, by instance id. The
## bookkeeping CardInstance.damaged_by_this_turn always wanted but never
## had (docs/ROADMAP.md): "half the damage dealt by one of those sorcery
## spells this turn" (Backdraft) is a question about amounts, not sources.
## Cleared at cleanup.
var damage_dealt_this_turn: Dictionary = {}

## Floating "when this creature dies this turn, ..." watches — the delayed
## dies-trigger the engine has no stack object for (CR 603.7a; see
## docs/ROADMAP.md). Each entry is {"instance_id": int,
## "callback": Callable(game, dead: CardInstance)}. Fired by
## _move_to_graveyard when that object actually DIES, then dropped;
## whatever is left is cleared at cleanup. Reincarnation is the pool's
## first user.
var death_watchers: Array[Dictionary] = []


## Floating "whenever this creature deals damage to a creature this turn,
## ..." watches (Runesword). Each entry is {"source_id": int,
## "callback": Callable(game, source, victim, amount)}. Fired by
## _land_damage_impl as the damage is marked, so the victim is still on the
## battlefield; cleared at cleanup.
var damage_watchers: Array[Dictionary] = []


## Watch damage [param inst] DEALS to creatures this turn (Runesword).
func watch_damage_dealt(inst: CardInstance, callback: Callable) -> void:
	if inst == null:
		return
	damage_watchers.append({"source_id": inst.id, "callback": callback})


## Watch for [param inst] dying THIS TURN and run [param callback] when it
## does — "when that creature dies this turn, ..." (Reincarnation). The
## watch outlives whatever placed it, which is the point (CR 603.6d).
func watch_death(inst: CardInstance, callback: Callable) -> void:
	if inst == null:
		return
	death_watchers.append({"instance_id": inst.id, "callback": callback})

## How many creatures DIED this turn (Khabál Ghoul, Osai Vultures,
## Scavenging Ghoul read it). Reset at cleanup with the other per-turn
## bookkeeping.
var creatures_died_this_turn := 0

## The CardData of every spell cast THIS TURN, per player id — index 0 is
## player 0's list, in casting order. Cards that count what has been cast
## (Ichneumon Druid's "other than the first instant spell that player
## casts each turn") read it; appended by cast_spell, cleared at cleanup.
var spells_cast_this_turn: Array = [[], []]

var log_lines := PackedStringArray()

# ------------------------------------------------- the mid-resolution ask --
#
# docs/duel-todo.md §1.3. The engine asks 81 questions in the middle of a
# resolution ("Pay {U} to keep Stasis?", "Choose a color", "Sacrifice an
# Island") and, being synchronous, cannot wait for a dialog.
#
# THE ANSWER IS A PRE-FLIGHT, NOT AN AWAIT (see [method _preflight]): a
# resolution that a human seat has an unanswered question in is RUN TWICE.
# The first run is a PROBE over a [GameSnapshot] — it is rewound, so nobody
# sees it — and all it is for is finding out what the card asks. The engine
# then HOLDS THE RESOLUTION OPEN on [member awaiting_choice], exactly as it
# already holds the turn open for attackers, blockers, the discard phase and
# the damage division, and the UI answers at leisure. The real run then
# resolves the card with the player's own answers parked on their agent.
#
# Every question is also filed here regardless, so a UI can show what was
# decided for the player when no one was asked.

## Every question asked this game, oldest first.
var choice_log: Array[PlayerChoice] = []

## The subset a seat that wanted to answer for itself did not answer — the
## honest ledger of what the referee decided on a human's behalf.
var unanswered_choices: Array[PlayerChoice] = []

## What each CARD asked the last time it resolved and asked anything, by
## card name. This is what lets a UI see a question coming: nearly every
## question in this pool is asked by an upkeep trigger that asks the same
## thing every turn.
var choice_history: Dictionary = {}

## The card whose resolution is running right now, "" outside one.
var _resolving_source := ""
var _resolving_choices: Array[PlayerChoice] = []

## The chosen targets of the object being resolved right now, flat and in
## slot order — read by cards through [method current_targets], set and
## restored by [method _run_effects] and by the TRIGGER branch of
## [method _run_item] (a targeted trigger's one target) alone.
var _resolving_targets: Array = []

## The MODE of the modal trigger being resolved right now
## (TriggeredAbility.modal; [member StackItem.mode]) — read by cards through
## [method current_mode], set and restored by the TRIGGER branch of
## [method _run_item] alone. 0 outside one.
var _resolving_mode := 0
var _resolving_delayed: Dictionary = {}

## WHAT THE COST OF THE ABILITY BEING RESOLVED ATE
## ([member StackItem.cost_paid]), for the duration of that resolution.
## Saved and restored around every item exactly as [member _resolving_targets]
## is, so a resolution nested inside another one (a copy, a trigger that
## resolves mid-resolution) cannot read the outer item's record. Cards ask
## through [method cost_paid].
var _resolving_cost: Dictionary = {}

## Who CONTROLS the object being resolved right now, -1 outside a
## resolution. "A spell or ability an opponent controls causes you to
## discard this card" (Psychic Purge) is the one question that needs it.
var _resolving_controller: int = -1

## The stack object being resolved right now — already popped off
## [member stack], so [method find_stack_item] cannot see it — null
## outside a resolution. A spell that copies ITSELF as it resolves (Chain
## Lightning's rider) reads its own targets, mode and X from here.
var _resolving_item: StackItem = null

## OPT IN to the pre-flight. Off by default, so the AI, the heuristic agent
## and every headless test resolve exactly as they always did; the DuelScreen
## turns it on because it has somewhere to put the question. A seat still has
## to say [method DecisionAgent.wants_to_be_asked] for anything to happen.
var interactive_choices := false

## The question a resolution is being HELD OPEN for, null when none. While
## it is set the item is back on top of the stack, untouched, and every
## action is refused until [method answer_choice] arrives — the same
## contract as awaiting_attackers / awaiting_discard.
var awaiting_choice: PlayerChoice = null

## True while a probe resolution is running: its log lines, its events, its
## state signals and its choice ledger are all suppressed, because the whole
## run is about to be rewound and a listener's reaction cannot be.
var _probing := false

## THE SEARCH JOURNAL, or null — and null is the default, so a normal duel
## pays one reference comparison per instrumented write and nothing else.
##
## When an [AiPlayer] search sets this, the mutation helpers below record
## the PREVIOUS value of what they are about to change (via [method _rec]
## and its cousins [method _rec_move], [method _rec_departure],
## [method _rec_stack_push], [method _rec_resolution]), so the search can
## unmake a move in time proportional to the MOVE rather than to the board
## — see `engine/undo_log.gd` for why that is the whole difference between
## a rewind and a fork, and for WHAT IS COVERED AND THE BOUNDARY: the
## helper surface, departures and resolutions as whole objects, the
## floating lists, and — since 2026-09-05, through [method _rec_turn] —
## the turn machinery, so a node may cross a step boundary.
## `tests/ai/test_undo_log.gd` pins the coverage move by move against
## [GameSnapshot].
##
## THE CONTRACT IS A PAIR: [method make_mark] opens a node,
## [method unmake_to] closes it, and [method end_search] hands the game
## back. A search that forgets `end_search` leaves the journal allocated,
## and the rest of the duel then records every mutation into a log nobody
## reads — slower and unbounded. `tests/ai/test_undo_log.gd` pins that
## ending a search really does put the game back to paying nothing.
var undo_log: UndoLog = null


## Note the current value of [param prop] on [param obj] for the search
## journal. Costs a null test when no search is running.
func _rec(obj: Object, prop: StringName) -> void:
	if undo_log != null:
		undo_log.record(obj, prop, obj.get(prop))


## A card is about to change zone ARRAYS: note its `zone`, the array of
## its current zone on BOTH seats (a stolen card sits on its controller's
## battlefield but its owner's everything else; recording both is cheaper
## than deciding), and the array it is about to be appended to. Callers
## then move the card however they did before. For a card leaving the
## BATTLEFIELD use [method _rec_departure] instead — it records far more.
func _rec_move(inst: CardInstance, to_pid: int, to_zone: int) -> void:
	if undo_log == null:
		return
	undo_log.record(inst, &"zone", inst.zone)
	if inst.zone == Mtg.Zone.HAND:   # the `zone` setter wipes these on leaving
		undo_log.record(inst, &"hand_lock_turn", inst.hand_lock_turn)
		undo_log.record(inst, &"revealed_in_hand", inst.revealed_in_hand)
	var from_field: StringName = ZONE_FIELD.get(inst.zone, &"")
	if from_field != &"":
		for p in players:
			undo_log.record(p, from_field, p.get(from_field))
	var to_field: StringName = ZONE_FIELD.get(to_zone, &"")
	if to_field != &"" and to_field != from_field:
		undo_log.record(players[to_pid], to_field, players[to_pid].get(to_field))


## A permanent is about to LEAVE the battlefield — through whichever door:
## graveyard, hand, exile, ante, phasing. [method
## CardInstance.clear_battlefield_state] wipes ~45 of its fields and
## `restore_printed_identity` swaps its `data`, so the whole object is
## recorded rather than the fields one by one; the departure also
## disturbs the battlefield lists, combat, the floating effects, the
## death watches and the dies count. [param to_pid]/[param to_zone] name
## where it lands (-1 for nowhere: phasing, a token ceasing to exist).
func _rec_departure(inst: CardInstance, to_pid := -1, to_zone := -1) -> void:
	if undo_log == null:
		return
	undo_log.record_object(inst)
	var seat := players[inst.controller_id]
	undo_log.record(seat, &"battlefield", seat.battlefield)
	undo_log.record(seat, &"phased_out", seat.phased_out)
	undo_log.record(self, &"_battlefield_order", _battlefield_order)
	undo_log.record(self, &"creatures_died_this_turn", creatures_died_this_turn)
	undo_log.record(self, &"death_watchers", death_watchers)
	undo_log.record_object(combat)
	continuous.record_all()
	if inst.is_token or inst.is_copy:
		undo_log.record(self, &"_instances", _instances)
	if to_pid >= 0:
		var to_field: StringName = ZONE_FIELD.get(to_zone, &"")
		if to_field != &"":
			undo_log.record(players[to_pid], to_field, players[to_pid].get(to_field))


## Something is about to go onto the stack outside [method cast_spell] and
## [method activate_ability]: a trigger, a copy of a spell.
func _rec_stack_push() -> void:
	if undo_log != null:
		undo_log.record(self, &"stack", stack)
		undo_log.record(self, &"_next_stack_id", _next_stack_id)


## A stack item is about to RESOLVE, and its card script may now write
## anything: onto its own card and its targets (card scripts set `memory`,
## `prevention`, the shields, `must_attack_this_turn` ... directly, outside
## the helpers), onto a few per-turn tables of the game and the players
## they fill by hand, and into the delayed-action pools the scheduling
## helpers keep. All of those are recorded whole here, once per
## resolution, which is what lets the journal cover a resolution the
## field-by-field helpers alone would not — see undo_log.gd, THE BOUNDARY.
func _rec_resolution(item: StackItem) -> void:
	if undo_log == null:
		return
	if item.card != null:
		undo_log.record_object(item.card)
	for ref in item.targets:
		if not ref.is_player:
			var target := find_instance(ref.instance_id)
			if target != null:
				undo_log.record_object(target)
	for field in RESOLUTION_TABLES:
		undo_log.record(self, field, get(field))
	for p in players:
		for field in PLAYER_RESOLUTION_FIELDS:
			undo_log.record(p, field, p.get(field))


## The per-turn state a RESOLUTION may write outside the zone/damage/stack
## helpers — the delayed-action pools ([method doom_at_next_end_step],
## [method schedule_end_step_action], [method watch_death] ...) and the
## tables card scripts assign to by hand. Recorded whole by
## [method _rec_resolution]; all small.
const RESOLUTION_TABLES: Array[StringName] = [
	&"_end_step_doom", &"_end_step_doom_if_attacked",
	&"_end_step_doom_unless_attacked", &"_end_step_doom_sacrifice",
	&"_end_step_tokens", &"_end_of_combat_doom", &"_control_until_eot",
	&"_end_of_combat_actions", &"_end_step_actions", &"_next_main_actions",
	&"life_on_damage_watchers", &"death_watchers", &"damage_watchers",
	&"extra_turns", &"combat_damage_prevented", &"no_attacks_this_turn",
	&"camouflage_this_turn", &"attacks_without_tapping",
	&"_one_shot_draws", &"delayed_triggers",
]
## The [MtgPlayer] fields a resolution may write by hand — every one a
## this-turn flag or shield the cleanup step clears — minus the ones
## [method ContinuousEffects.recalculate] rebuilds from statics.
const PLAYER_RESOLUTION_FIELDS: Array[StringName] = [
	&"life_for_mana", &"any_color_spells", &"reverse_damage_sources",
	&"land_mana_becomes", &"may_take_creature_damage", &"paid_prevention",
	&"prevention_shields", &"prevention_shield_filters",
	&"damage_replacements", &"damage_prevention", &"poison",
	&"untapped_lands_at_turn_start",
]


## THE TURN MACHINERY'S OWN STATE (2026-09-05) — what [method _advance_step],
## [method _enter_step], [method _next_turn] and the turn-based actions they
## run write DIRECTLY, outside the mutation helpers. Recorded whole by
## [method _rec_turn] at every step boundary, which is what lets a search
## node CROSS one: until this list existed the journal's documented
## boundary was the turn machinery, and `engine/ai/combat_search.gd` had to
## run over a flat model instead of over the engine itself.
##
## HAND-LISTED rather than taken with [method UndoLog.record_object],
## which is what a departure and a resolution use. [MtgGame] also carries
## the three things a per-boundary record must NOT copy — `log_lines`
## (thousands of strings by turn 20), `_instances`, and the battlefield
## caches — and `record_object` would duplicate all of them every time a
## step changed. Everything on this list is a scalar or a small container.
##
## What is deliberately NOT here, because something else already covers it:
## the zone arrays and `life` (their helpers record them), `_instances` and
## `_battlefield_order` ([method _rec_departure]), the mana pools and
## `rng.state` ([method make_mark]), `cur_*` and the player-level static
## flags (rebuilt by [method ContinuousEffects.recalculate] — see
## `engine/undo_log.gd`, PRIMARY STATE ONLY), and the per-turn pools of
## [constant RESOLUTION_TABLES], which [method _rec_turn] records as well.
const TURN_FIELDS: Array[StringName] = [
	# where the turn is
	&"_step_index", &"turn_number", &"active_player", &"priority_player",
	&"_passes", &"_skip_first_draw",
	# the steps that hold themselves open
	&"awaiting_attackers", &"awaiting_blockers", &"awaiting_discard",
	&"discard_count",
	# the combat damage step's own bookkeeping
	&"_first_strike_ids", &"_damage_requests", &"_damage_splits",
	&"_damage_cursor", &"_wave_assigned", &"awaiting_damage_assignment",
	&"awaiting_damage_prevention", &"awaiting_regeneration",
	&"regeneration_candidates", &"damage_pending",
	# the per-turn tallies CLEANUP empties wholesale — each is journaled
	# at its own write site as well, but nothing else records the wipe
	&"damage_dealt_this_turn", &"creatures_died_this_turn",
	&"spells_cast_this_turn",
	# a turn-based action can end the duel (the 1997 phase-end life check)
	&"game_over", &"winner", &"is_draw",
	# and the question machinery a turn-based action may open
	&"awaiting_choice", &"unanswered_choices", &"_resolving_choices",
	&"choice_log", &"choice_history", &"_pending_action", &"_held_answered",
	&"_turn_source", &"_cost_answers", &"_cost_asked", &"_cost_values",
	&"_replaying_cost", &"_cost_source", &"_announced_tops",
	&"_defer_state_based_actions", &"_defer_depth",
]

## The [MtgPlayer] fields the turn machinery writes on top of
## [constant PLAYER_RESOLUTION_FIELDS] — the untap sweep's counters, the
## draw step's per-step tally, and the per-turn flags cleanup wipes.
const TURN_PLAYER_FIELDS: Array[StringName] = [
	&"draws_this_step", &"lands_played_this_turn", &"attacked_this_turn",
	&"acted_this_turn", &"acted_last_turn", &"artifact_damage_this_turn",
	&"damage_taken_this_turn", &"drawn_this_turn", &"has_lost",
	&"mana_substitutions", &"damage_caps",
]

## The [CardInstance] fields the UNTAP STEP writes on every permanent
## (CR 502.2-502.3) plus the per-turn combat flags it clears for both
## seats. `tapped` is recorded at its own site, where the step already
## knows which permanents actually change.
const UNTAP_INSTANCE_FIELDS: Array[StringName] = [
	&"skip_next_untap", &"skip_untaps", &"summoning_sick",
	&"cant_attack_this_turn", &"cant_attack_next_turn",
	&"attacked_this_turn", &"could_attack_this_turn",
]


## Note the whole turn machinery's state before a step boundary changes it.
##
## Called at the top of [method _advance_step] and of [method _enter_step]
## — both, because either can be entered on its own ([method answer_choice]
## re-runs a held step, [method _next_turn] enters step 0 directly) and a
## duplicate record is free: [method UndoLog.undo_to] replays backwards, so
## the older value is written last and wins.
##
## COST, measured on the same workload as `engine/undo_log.gd`'s own
## figures: about 90 records, ~12 us — against the ~3.4 ms a
## [GameSnapshot] of the same board costs. Paid only while a search is
## running; a normal duel pays one null test.
func _rec_turn() -> void:
	if undo_log == null:
		return
	for field in TURN_FIELDS:
		undo_log.record(self, field, get(field))
	for field in RESOLUTION_TABLES:
		undo_log.record(self, field, get(field))
	for p in players:
		for field in PLAYER_RESOLUTION_FIELDS:
			undo_log.record(p, field, p.get(field))
		for field in TURN_PLAYER_FIELDS:
			undo_log.record(p, field, p.get(field))
	# Combat is emptied wholesale at the top of declare-attackers and again
	# as the combat phase ends, and the floating effects expire at three
	# different boundaries; both are small and both record themselves whole.
	undo_log.record_object(combat)
	continuous.record_all()


## Open a search node. Returns the mark [method unmake_to] takes back; the
## journal records `rng.state` here so exploring cannot move the real
## game's random stream (CONTRIBUTING.md rule 7). The FIRST call allocates the
## journal and puts the game into probe mode — [method end_search] is what
## takes both away again, and it is not optional.
func make_mark() -> int:
	if undo_log == null:
		undo_log = UndoLog.new()
		continuous.journal = undo_log
	var m := undo_log.mark(self)
	# A search node IS a probe: its log lines never happened, its signals
	# must not reach a UI, and its questions must not hold a resolution
	# open. [member _probing] already means all three, so a search reuses
	# it rather than inventing a second flag — and the journal puts it back.
	undo_log.record(self, &"_probing", _probing)
	_probing = true
	# The MANA POOLS are recorded here rather than at their eight mutation
	# sites: two small dictionaries a side, touched by nearly every move,
	# and cheaper to save unconditionally than to instrument.
	for pl in players:
		undo_log.record(pl.mana_pool, &"_mana", pl.mana_pool._mana)
		undo_log.record(pl.mana_pool, &"_restricted", pl.mana_pool._restricted)
	return m


## Unmake every recorded change back to [param mark] and rebuild the
## derived layer. The journal carries PRIMARY state only; `cur_*` and the
## player-level static flags come back from the CR 613 pipeline, which is
## what makes the journal small enough to be worth having.
func unmake_to(mark: int) -> void:
	if undo_log == null:
		return
	undo_log.undo_to(mark)
	# The battlefield cache and the derived indexes are rebuilt, not
	# journaled: `all_battlefield()` regenerates both from
	# `_battlefield_order`, which IS journaled, and `recalculate()` asks
	# for them on its first line.
	_battlefield_dirty = true
	continuous.recalculate(self)


## Hand the game back after a search: drop the journal so a normal duel
## stops recording, and stop probing. Unwind to the ROOT mark first —
## `end_search` throws the journal away rather than replaying it, so
## anything still outstanding is lost, not undone.
func end_search() -> void:
	if undo_log != null:
		undo_log.clear()
		undo_log = null
	continuous.journal = null
	_probing = false

## How many of the current item's questions the player had answered the
## last time the engine held it open, -1 before the first hold. If a probe
## comes back with no MORE of them answered than last time, the answer that
## was parked is not being served — a bug rather than a new question — so
## the engine resolves for real rather than hold the duel open forever.
var _held_answered := -1

# ------------------------------------------------------ the COST hold --
#
# docs/duel-todo.md §1.3's last four rows, and the one family of questions
# the pre-flight above cannot reach. A COST is assembled and paid BEFORE the
# spell it pays for is on the stack (CR 601.2h), and a mana ability never
# touches the stack at all (CR 605.3a) — so there is no stack item to probe.
#
# They do not need one. Every one of these asks happens at a point where the
# whole cost has been checked (no refusal is left) and NOTHING has been
# mutated yet, so the hold is simply a RECORD OF THE ACTION TO RE-ISSUE:
# [method answer_choice] parks the player's answer on their agent and calls
# the same action again, which now serves it from the mailbox instead of
# asking. Cheaper than a rewind point, and it cannot drift out of sync with
# the state, because there is no saved state to drift.

## The action a cost question is holding open — {} when none. Keys: "kind"
## (`cast` / `activate` / `mana`), "pid", "inst", and whatever that action
## needs to be re-issued ("targets", "x", "mode", "index").
var _pending_action: Dictionary = {}

## How many of the pending action's cost questions the player has ALREADY
## answered, and how many the run in progress has asked. A replayed action
## must serve the answers it has and stop on the NEXT question rather than
## re-ask the first — these two counters are the whole of that bookkeeping,
## and they are what stops a card with two cost questions looping forever.
var _cost_answers := 0
var _cost_asked := 0

## The answers themselves, in the order they were given. Each is parked on
## the seat JUST IN TIME — inside [method _hold_cost_choice], at the moment
## the replay reaches the question it answers — never up front. Parking
## them all at once broke an action with two questions of the same kind:
## the replay's re-ask of the FIRST question took the SECOND answer from the
## mailbox (the first had been spent by the previous replay), so a card
## with a repeated cost question was served its answers shifted by one.
var _cost_values: Array = []

## True for exactly the one action call [method answer_choice] re-issues, so
## that call keeps [member _cost_answers] instead of resetting it.
var _replaying_cost := false

## The card whose COST is being paid right now, "" outside one. A cost
## question wears it as its `source` (see [method current_resolution_source])
## so the answer the player parks is matched to the card that asked for it,
## exactly as a resolution's questions are.
var _cost_source := ""

## The card whose TURN-BASED ACTION is asking a question right now (a
## Smoke choosing which creature untaps, an Old Man of the Sea choosing
## not to), "" outside one. Scopes the question the way [member _cost_source]
## scopes a cost's, without making it a cost (see [method is_paying_cost]).
var _turn_source := ""

var _next_instance_id := 1
## Packet ids are handed out per GAME and never reused: a [TargetRef] that
## names damage names it by this id, so recycling one would silently
## re-point a chosen target (see [DamagePacket]).
var _next_packet_id := 1

## Ids for stack items, so a [TargetRef] can name an ABILITY on the stack
## (which has no card of its own — Rust, Ayesha Tanaka). Never reused, for
## the same reason packet ids never are: "the ability you aimed at has
## resolved" has to stay detectable.
var _next_stack_id := 1
var _instances: Dictionary = {}        # id -> CardInstance
var _battlefield_order: Array[int] = [] # instance ids in entry (timestamp) order
## Cached [method all_battlefield] result + its staleness flag and the
## derived "who listens for what" index. See all_battlefield().
var _battlefield_cache: Array[CardInstance] = []
var _battlefield_dirty := true
var _trigger_index: Dictionary = {}
var _battlefield_statics: Array[CardInstance] = []
## The permanents whose statics change TYPES (CR 613 layer 4) — the tiny
## first pass of the continuous pipeline.
var _battlefield_type_statics: Array[CardInstance] = []
var _battlefield_cost_modifiers: Array[CardInstance] = []

## The permanents carrying a CR 614 draw replacement / draw-STEP replacement,
## rebuilt with the rest of the battlefield index. Both are empty in almost
## every duel, which is what keeps _replace_draw off the hot path.
var _battlefield_draw_replacements: Array[CardInstance] = []
var _battlefield_draw_step_replacements: Array[CardInstance] = []
## Permanents carrying a rare state-based clause (legend/world supertype,
## Aura, "sacrifice this when ..."). check_state_based_actions walks only
## these for the expensive checks.
var _sba_watch: Array[CardInstance] = []
var _skip_first_draw := true            # the starting player skips turn 1's draw
## The instance id last announced as each player's revealed library top
## (Field of Dreams), so [method _emit_state] logs a top card once, when
## it becomes the top; -1 = nothing announced.
var _announced_tops: Array[int] = [-1, -1]
## True while a SIMULTANEOUS batch of mutations is being applied: state-based
## actions wait until all of it has landed, so a creature that dies to the
## first packet still deals its own damage AND still hears its damage
## triggers (CR 510.4 / 704.3). Set through
## [method begin_simultaneous] / [method end_simultaneous].
var _defer_state_based_actions := false
## How many nested [method begin_simultaneous] calls are open.
var _defer_depth := 0
## Who had FIRST STRIKE when the first combat damage step began (CR 510.5).
## Frozen there and read again by the normal damage step, so a creature
## that gains or loses first strike in the priority window between the two
## still strikes exactly once. Cleared as each declare-attackers step opens.
var _first_strike_ids: Dictionary = {}
## The current damage step's planned divisions, the answers gathered so
## far, and which one is being asked about. See _collect_damage_requests.
var _damage_requests: Array = []
var _damage_splits: Array = []
var _damage_cursor := 0
## Damage this step has already assigned, per instance id — what "lethal"
## is measured against as the divisions are answered one by one.
var _wave_assigned: Dictionary = {}


# -------------------------------------------------------------------- setup --

## Build a two-player game. Decks are card-name lists resolved through the
## CardRegistry. Unknown names error loudly. Both libraries are shuffled
## with [param seed_value]; pass a fixed seed in tests for reproducibility.
func setup(deck0: Array, deck1: Array, name0 := "Player 1", name1 := "Player 2",
		life0 := 20, life1 := 20, seed_value := 0) -> void:
	CardRegistry.ensure_loaded()
	# Determinism (CONTRIBUTING.md rule 7): 0 is an ordinary seed like any other —
	# the Deck Lab derives per-game seeds arithmetically and would otherwise
	# leave exactly one game of a `--seed 0` run unreproducible. Pass
	# [param seed_value] = -1 for a deliberately random game.
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	players = [MtgPlayer.new(0, name0, life0), MtgPlayer.new(1, name1, life1)]
	agents = [DecisionAgent.new(), DecisionAgent.new()]
	_build_library(0, deck0)
	_build_library(1, deck1)
	for p in players:
		_shuffle(p.library)
	log_line("Game set up: %s (%d cards) vs %s (%d cards)" % [
		name0, deck0.size(), name1, deck1.size()])


## Deal opening hands and begin turn 1 in one call — no mulligan offered.
## [param first_player] is who goes first; tools that alternate explicitly
## (the Deck Lab) pass 0 and swap decks instead. A driver that WANTS the
## mulligan (the duel screen) calls [method deal_opening_hands], runs the
## offers, and then [method start_duel].
func start(opening_hand := 7, first_player := 0) -> void:
	deal_opening_hands(opening_hand)
	start_duel(first_player)


# ------------------------------------------------------- the opening hand --
#
# THE SHANDALAR MULLIGAN (docs/duel-todo.md §1.5, §6.2). `Duel.hlp`, topic
# "Mulligan": *"If either player draws no land in this seven cards or draws
# all land, then that player has the option to declare a mulligan… that
# player must shuffle her hand back into her library and draw seven new
# cards… The other player has the option to do so as well… Each player has
# only one chance to redraw, and once that's used or waived, the duel
# begins."*
#
# Seven for seven. No bottoming, no descending count: this is neither the
# Paris nor the London mulligan, and the `mulligan to %d` strings in the
# top-level string table are Manalink 3's, not the 1997 game's.

## True while the opening-hand phase is running and mulligans may be taken.
var mulligan_open := false

## Whether each seat's ONE chance is gone — spent by redrawing or waived.
var mulligan_used: Array[bool] = [false, false]

## Whether each seat actually redrew. Read by [method may_mulligan], which
## is what opens the offer to the other player.
var mulligan_taken: Array[bool] = [false, false]


## Deal both opening hands and open the mulligan phase. The duel does not
## begin until [method start_duel].
func deal_opening_hands(opening_hand := 7) -> void:
	mulligan_used.fill(false)
	mulligan_taken.fill(false)
	mulligan_open = true
	for p in players:
		draw_cards(p.id, opening_hand)
	_emit_state()


## Does [param pid]'s hand qualify on its own account — no land at all, or
## nothing but land? (An empty hand qualifies for neither.)
func hand_is_a_mulligan_hand(pid: int) -> bool:
	var hand := players[pid].hand
	if hand.is_empty():
		return false
	var lands := 0
	for inst in hand:
		if inst.is_land():
			lands += 1
	return lands == 0 or lands == hand.size()


## May [param pid] still redraw? Their own hand qualifies, OR the opponent
## has already redrawn and this is the courtesy offer — and either way only
## while their one chance is unspent.
func may_mulligan(pid: int) -> bool:
	if not mulligan_open or game_over:
		return false
	if pid < 0 or pid >= players.size() or mulligan_used[pid]:
		return false
	return hand_is_a_mulligan_hand(pid) or mulligan_taken[opponent_of(pid)]


## Take the mulligan: the whole hand is shuffled back and the same number
## of cards drawn again. "" on success, else a refusal string.
func take_mulligan(pid: int) -> String:
	if not may_mulligan(pid):
		return "no mulligan is available to %s" % players[pid].player_name \
			if pid >= 0 and pid < players.size() else "no such player"
	var p := players[pid]
	var count := p.hand.size()
	for inst in p.hand:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.hand.clear()
	_shuffle(p.library)
	draw_cards(pid, count)
	mulligan_used[pid] = true
	mulligan_taken[pid] = true
	# `@DIALOG_MULLIGAN` entry 7, Program/UIStrings.txt:499.
	log_line("%s has chosen to take a mulligan" % p.player_name)
	_emit_state()
	return ""


## Waive the chance. Per `Duel.hlp` a waiver is as final as a redraw.
func decline_mulligan(pid: int) -> String:
	if not mulligan_open:
		return "the opening hand is already settled"
	if pid < 0 or pid >= players.size():
		return "no such player"
	mulligan_used[pid] = true
	# `@DIALOG_MULLIGAN` entry 8.
	log_line("%s did not take a mulligan" % players[pid].player_name)
	_emit_state()
	return ""


## Close the opening hand and begin turn 1. [param first_player] plays
## first and therefore skips their first draw (`Duel.hlp`, "Play or Draw
## Rule" — the toss winner picks which of the two they want).
func start_duel(first_player := 0) -> void:
	mulligan_open = false
	turn_number = 1
	active_player = clampi(first_player, 0, 1)
	_skip_first_draw = true
	log_line("== Turn %d — %s ==" % [turn_number, players[active_player].player_name])
	_enter_step(0)


func _build_library(pid: int, names: Array) -> void:
	for n in names:
		var data := CardRegistry.get_card(n)
		if data == null:
			continue
		var inst := CardInstance.new(data, _next_instance_id, pid)
		_next_instance_id += 1
		_instances[inst.id] = inst
		players[pid].library.append(inst)


## Fisher–Yates with the game RNG (never Array.shuffle(): that uses the
## global RNG and would break reproducibility).
func _shuffle(cards: Array[CardInstance]) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


# ------------------------------------------------------------------ queries --

## The current Mtg.Step.
func current_step() -> int:
	return Mtg.STEP_ORDER[_step_index]

## The seat with id [param pid] (0 or 1).
func player(pid: int) -> MtgPlayer:
	return players[pid]

## The other seat. Two-player only by design (docs/ROADMAP.md); every
## "each opponent" clause in the 1997 pool has exactly one answer here.
func opponent_of(pid: int) -> int:
	return 1 - pid

## The CardInstance with this id, or null. Ids are stable for the whole
## game and are how TargetRef, the UI and every delayed effect refer to
## objects — never by pointer, so a stale reference cannot resurrect one.
func find_instance(id: int) -> CardInstance:
	return _instances.get(id)

## Every battlefield permanent, both players, in entry (timestamp) order —
## the iteration order the continuous-effects pipeline relies on.
##
## PERFORMANCE: this is the engine's most-called query (the continuous
## pipeline, every state-based-action pass, ~70 card statics), so the list
## is CACHED and rebuilt only when the battlefield actually changes. The
## rebuild always produces a BRAND NEW array and never mutates the one it
## handed out, so a caller iterating the result while permanents die keeps
## a stable snapshot — the same guarantee the old copy-every-time version
## gave. Callers must treat the result as READ-ONLY.
func all_battlefield() -> Array[CardInstance]:
	if _battlefield_dirty:
		var out: Array[CardInstance] = []
		out.resize(_battlefield_order.size())
		var i := 0
		for id in _battlefield_order:
			out[i] = _instances[id]
			i += 1
		_battlefield_cache = out
		_rebuild_battlefield_index()
		_battlefield_dirty = false
	return _battlefield_cache


## The battlefield permanents that actually carry STATIC abilities, in
## timestamp order. Most permanents (lands, vanilla creatures) carry none,
## so the continuous pipeline walks this short list instead of the whole
## board — twice per recalculation, once per CR 613 sublayer.
func battlefield_with_statics() -> Array[CardInstance]:
	all_battlefield()   # refreshes the index when stale
	return _battlefield_statics


## The battlefield permanents carrying a TYPE-CHANGING static (CR 613 layer
## 4) — Blood Moon, Evil Presence, Kormus Bell, Titania's Song — or an
## ability-REMOVING one (layer 6), which the pipeline runs before them.
## Usually empty, which is why the pipeline's first passes cost nothing.
func battlefield_with_type_statics() -> Array[CardInstance]:
	all_battlefield()
	return _battlefield_type_statics


## Derived indexes rebuilt with the battlefield cache:
## - [member _trigger_index]: which Mtg.EventType values ANY permanent
##   listens for, so dispatch_event can skip building a listener list for
##   the (very common) event nobody cares about;
## - [member _battlefield_statics] / [member _battlefield_cost_modifiers]:
##   the permanents worth iterating for continuous effects and for spell/
##   ability surcharges.
func _rebuild_battlefield_index() -> void:
	_trigger_index.clear()
	_battlefield_statics.clear()
	_battlefield_type_statics.clear()
	_battlefield_cost_modifiers.clear()
	_battlefield_draw_replacements.clear()
	_battlefield_draw_step_replacements.clear()
	_sba_watch.clear()
	for inst in _battlefield_cache:
		for trig in inst.data.triggered_abilities:
			_trigger_index[trig.event_type] = true
		if not inst.data.static_abilities.is_empty():
			_battlefield_statics.append(inst)
			for st in inst.data.static_abilities:
				# Granted triggers (Energy Flux) are appended to OTHER
				# permanents' live lists by the recalculation that follows
				# this rebuild, so the granting static declares them.
				for granted_type in st.grants_trigger_types:
					_trigger_index[granted_type] = true
				# The EARLY passes' sources: layer 4 (types) and layer 6
				# (silencing). A silencer that changed no types used to be
				# missing from this list, so its layer-6 pass never saw it
				# and it ran late, in the general pass (2026-09-02).
				if st.changes_types or st.silences_abilities:
					_battlefield_type_statics.append(inst)
					break
		if not inst.data.cost_modifier.is_empty():
			_battlefield_cost_modifiers.append(inst)
		# Draws happen thousands of times a duel and almost nothing replaces
		# them, so the scan is indexed exactly like the statics are.
		if inst.data.draw_replacement.is_valid():
			_battlefield_draw_replacements.append(inst)
		if inst.data.draw_step_replacement.is_valid():
			_battlefield_draw_step_replacements.append(inst)
		if (inst.data.supertypes & (Mtg.Supertype.LEGENDARY | Mtg.Supertype.WORLD)) != 0 \
				or inst.data.is_aura() \
				or inst.data.sacrifice_if_you_control_subtype != "" \
				or inst.data.sacrifice_if_no_land_type != "" \
				or inst.data.sacrifice_condition.is_valid():
			_sba_watch.append(inst)


## Does ANY permanent on the battlefield subscribe to [param type]? Reads
## the same index [method dispatch_event] uses for its early-out, so a
## caller on a hot path can skip BUILDING the event as well as dispatching
## it. Only worth asking where the event is dispatched thousands of times a
## duel and heard by almost nothing — [method tap_for_mana]'s
## ABILITY_ACTIVATED, which runs for every land every turn.
func has_trigger_listener(type: int) -> bool:
	all_battlefield()
	return _trigger_index.has(type)


## Mark the battlefield snapshot stale. Called by every helper that adds
## to or removes from [member _battlefield_order].
func _battlefield_changed() -> void:
	_battlefield_dirty = true

## Find a battlefield permanent of [param pid] by card name (test/AI sugar).
func find_on_battlefield(pid: int, card_name: String) -> CardInstance:
	for inst in players[pid].battlefield:
		if inst.data.card_name == card_name:
			return inst
	return null

## Find a card in [param pid]'s hand by name.
func find_in_hand(pid: int, card_name: String) -> CardInstance:
	for inst in players[pid].hand:
		if inst.data.card_name == card_name:
			return inst
	return null


# ----------------------------------------------------------- player actions --
# All return "" on success or a refusal reason. See class doc.

## Play a land from hand (special action — no stack, CR 305).
func play_land(pid: int, inst: CardInstance) -> String:
	var err := _act_precheck(pid)
	if err != "":
		return err
	if not inst.is_land():
		return "%s is not a land" % inst.data.card_name
	if inst.zone != Mtg.Zone.HAND or inst.owner_id != pid:
		return "that land is not in your hand"
	var locked_why := hand_lock_reason(inst)
	if locked_why != "":
		return locked_why
	# CR 305.1: playing a land is a special action, taken only by a player
	# who HAS priority (during their own main phase, with an empty stack).
	if priority_player != pid:
		return "you don't have priority"
	if pid != active_player or not Mtg.is_main_step(current_step()) or not stack.is_empty():
		return "lands can only be played in your main phase with an empty stack"
	# A spell can deal damage in a main phase, so the window really can be
	# open here. `Duel.hlp`: "No other kind of fast effects or spells are
	# permitted" — and a land drop is not a prevention effect (§6.8).
	if awaiting_damage_prevention or awaiting_regeneration:
		return "no other kind of fast effects or spells are permitted " \
			+ "during damage prevention"
	if players[pid].lands_played_this_turn >= 1 and not unlimited_land_plays.has(pid):
		return "you already played a land this turn"
	var land_banned_by := play_banned(pid, inst.data)
	if land_banned_by != "":
		return "%s can't be played (%s)" % [inst.data.card_name, land_banned_by]
	# "Lands can't enter the battlefield" is a SECOND, separate prohibition
	# (Worms of the Earth prints both lines). Asked here, before the card
	# leaves the hand and before the land drop is spent, so a player who
	# tries it is REFUSED rather than silently charged for nothing
	# (CONTRIBUTING.md rule 3).
	var entry_banned_by := entry_refused(inst, pid)
	if entry_banned_by != "":
		return "%s can't enter the battlefield (%s)" % [
			inst.data.card_name, entry_banned_by]
	if undo_log != null:
		_rec(players[pid], &"hand")
		_rec(players[pid], &"lands_played_this_turn")
	players[pid].hand.erase(inst)
	players[pid].lands_played_this_turn += 1
	_put_on_battlefield(inst, pid)
	dispatch_event(Mtg.EventType.LAND_PLAYED, {"instance": inst, "controller": pid})
	log_line("%s plays %s" % [players[pid].player_name, inst.data.card_name])
	return ""


## Activate a mana ability (tap a land / Sol Ring...). Does not use the
## stack (CR 605.3) and needs no priority — usable any time you could pay
## a cost. [param ability_index] picks among the card's mana abilities.
## CHANNEL: "any time you could activate a mana ability, you may pay 1
## life. If you do, add {C}." A player-level mana source, so it is an
## ACTION on the game rather than an ability on a permanent — the UI, the
## AI and a test all reach it the same way, and it obeys the same timing
## gate [method tap_for_mana] does (CR 605.3a: any time a cost could be
## paid, including in the middle of paying one).
##
## Life may be paid down to exactly 0 (CR 118.4), and the state-based
## actions then do what they always do — which is the whole Channel-Fireball
## story.
func pay_life_for_mana(pid: int, amount := 1) -> String:
	if game_over:
		return "the game is over"
	if awaiting_choice != null:
		return "waiting for a choice to be made"
	if pid < 0 or pid >= players.size():
		return "no such player"
	if not players[pid].life_for_mana:
		return "you have no way to turn life into mana"
	if amount <= 0:
		return "pay at least 1 life"
	if players[pid].life < amount:
		return "not enough life to pay %d" % amount
	adjust_life(pid, -amount)
	players[pid].mana_pool.add(Mtg.ManaColor.C, amount)
	log_line("%s channels %d life into {C}" % [players[pid].player_name, amount])
	_emit_state()
	return ""


## Grant [param pid] Guardian Angel's rider on [param target]: "until end
## of turn, you may pay {1} any time you could cast an instant. If you do,
## prevent the next 1 damage that would be dealt to that permanent or
## player this turn." Spent through [method pay_for_prevention]; one entry
## per resolution, so two Angels on the same Bears are two permissions
## that each cost {1} per point — which is the same as one, and the
## duplicate is kept only so the log can name both.
func grant_paid_prevention(pid: int, target: TargetRef, desc: String) -> void:
	if target == null or target.is_damage or target.is_ability:
		return
	if not target.is_player:
		var inst := find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
	_rec(players[pid], &"paid_prevention")
	players[pid].paid_prevention.append({"target": target, "desc": desc})
	log_line("%s may pay {1} to prevent 1 more damage to %s this turn (%s)" % [
		players[pid].player_name, target_label(target), desc])


## The rider [param pid] holds on [param target], or an empty Dictionary.
## The UI's "can this be bought?" question and the AI's; the action itself
## is [method pay_for_prevention].
func paid_prevention_for(pid: int, target: TargetRef) -> Dictionary:
	if target == null or pid < 0 or pid >= players.size():
		return {}
	for entry in players[pid].paid_prevention:
		if (entry["target"] as TargetRef).same_object(target):
			return entry
	return {}


## Every seat's riders on the object that just left the battlefield
## (CR 400.7). Called from the leave seam, so a Bears that is bounced and
## replayed the same turn is not "that permanent".
func _drop_paid_prevention_for(instance_id: int) -> void:
	for p in players:
		for i in range(p.paid_prevention.size() - 1, -1, -1):
			var ref: TargetRef = p.paid_prevention[i]["target"]
			if not ref.is_player and ref.instance_id == instance_id:
				_rec(p, &"paid_prevention")
				p.paid_prevention.remove_at(i)


## PAY {1} for one more point of prevention on [param target] (Guardian
## Angel's rider — see [method grant_paid_prevention]). "Any time you could
## cast an instant" is priority (CR 117.1a), the 1997 damage-prevention
## step included — that step is where the original's `@GUARDIAN_EFFECT`
## prompt ("Select a damage card.") lived — and never the regeneration
## step, which admits regeneration only. Paying does not use the stack:
## the point goes straight into the target's prevention pool, the same
## pool the spell's own X fills, and the pool is what
## [method _land_damage] draws down when damage lands. The 1997 game had
## no stack to put it on; under the CR it is an effect of the resolved
## spell, not an activated ability (CR 113.3b is "[Cost]: [Effect]"), so
## there is nothing to respond to either way.
func pay_for_prevention(pid: int, target: TargetRef) -> String:
	var err := _act_precheck(pid)
	if err != "":
		return err
	if priority_player != pid:
		return "you don't have priority"
	if awaiting_regeneration:
		return "only regeneration effects may be used now"
	var entry := paid_prevention_for(pid, target)
	if entry.is_empty():
		return "you have no prevention to buy for %s" % (
			"that" if target == null else target_label(target))
	var inst: CardInstance = null
	if not target.is_player:
		inst = find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return "%s is no longer on the battlefield" % target_label(target)
	var one := ManaCost.parse("{1}")
	var pool: ManaPool = players[pid].mana_pool
	var subs: Array = players[pid].mana_substitutions
	if not pool.can_pay(one, 0, [], subs):
		return "can't pay {1}"
	pool.pay(one, 0, [], subs)   # not undoable (CR 601.2h), like any cost
	if inst != null:
		_rec(inst, &"prevention")
		inst.prevention += 1
	else:
		_rec(players[target.player_id], &"damage_prevention")
		players[target.player_id].damage_prevention += 1
	log_line("%s pays {1}: %s will prevent the next 1 damage to %s this turn" % [
		players[pid].player_name, String(entry["desc"]), target_label(target)])
	_emit_state()
	return ""


func tap_for_mana(pid: int, inst: CardInstance, ability_index := 0) -> String:
	_begin_cost_choices()
	if game_over:
		return "the game is over"
	# A mana ability skips [method _act_precheck] on purpose — CR 605.3a lets
	# one be activated any time a cost could be paid, including in the middle
	# of paying one. It still must not run while the duel is HELD OPEN on a
	# question, which is the one hold this method can raise itself.
	if awaiting_choice != null:
		return "waiting for a choice to be made"
	if inst.zone != Mtg.Zone.BATTLEFIELD or inst.controller_id != pid:
		return "you don't control that permanent"
	# LIVE mana abilities: a land turned into a Swamp taps for {B}.
	if inst.cur_mana_abilities.is_empty():
		return "%s has no mana ability" % inst.data.card_name
	if ability_index < 0 or ability_index >= inst.cur_mana_abilities.size():
		return "no such mana ability"
	var ability: ManaAbility = inst.cur_mana_abilities[ability_index]
	# {T} in the cost: the usual case. Ashnod's Altar-style abilities skip
	# both the tap and (CR 302.6) the summoning-sickness gate.
	if ability.taps_source:
		if inst.tapped:
			return "%s is already tapped" % inst.data.card_name
		if inst.is_creature() and inst.summoning_sick \
				and not inst.has_keyword(Mtg.Keyword.HASTE):
			return "summoning sickness (CR 602.5g applies to {T} mana abilities too)"
	# "Sacrifice a <filter>" costs need a legal body BEFORE anything is paid.
	# LEGALITY only — which body goes is asked below, once nothing can still
	# refuse (CR 601.2h; cast_spell carries the same split).
	var mana_bodies: Array[CardInstance] = []
	var mana_sacrifice: CardInstance = null
	if ability.sacrifice_filter.is_valid():
		for perm in players[pid].battlefield:
			# A MANA ability's sacrifice cost always eats ANOTHER permanent
			# (ManaAbility has no self-eating flag): nothing in the pool
			# sacrifices the land it is tapping for mana.
			if perm != inst and ability.sacrifice_filter.call(perm):
				mana_bodies.append(perm)
		if mana_bodies.is_empty():
			return "no %s to sacrifice" % ability.sacrifice_filter_desc
	# "Remove a dream counter: Add {C}" (Rasputin Dreamweaver) — the
	# counters come off with the rest of the cost (CR 601.2h).
	if ability.counter_cost_kind != "" \
			and int(inst.counters.get(ability.counter_cost_kind, 0)) \
				< ability.counter_cost_count:
		return "not enough %s counters to remove" % ability.counter_cost_kind
	# CR 601.2h: the WHOLE cost is checked before any part of it is paid —
	# a refused activation must leave the pool, the counters and the
	# permanent exactly as they were.
	if ability.life_cost > 0 and players[pid].life < ability.life_cost:
		return "not enough life to pay %d" % ability.life_cost
	# Costed mana abilities ("{2}, {T}: Add …" — Celestial Prism, Coal
	# Golem) pay from the FLOATING pool only (they resolve mid-payment).
	if ability.cost != null and not players[pid].mana_pool.can_pay(ability.cost):
		return "not enough floating mana (%s)" % ability.cost.text
	# THE COST IS PAYABLE — ask now, not before, and nothing below this line
	# can refuse. That is what lets both questions HOLD THE DUEL OPEN with
	# nothing but a record of this call to re-issue (docs/duel-todo.md §1.3):
	# there is no stack item to probe, and nothing to rewind either.
	var replay := {"kind": "mana", "pid": pid, "inst": inst,
		"index": ability_index}
	if not mana_bodies.is_empty():
		var body_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
			PlayerChoice.sacrifice_prompt(ability.sacrifice_filter_desc))
		body_q.candidates = mana_bodies
		if _hold_cost_choice(body_q, replay):
			return ""
		mana_sacrifice = _ask_cost_card(pid, inst, mana_bodies, body_q.prompt)
	# "Add one mana of any color that ..." (Fellwar Stone): the COLOUR is
	# part of activating the ability, not of resolving anything, so the
	# engine asks it here rather than the card asking from inside
	# `dynamic_color` — this is the only point in the activation where the
	# duel can still be held open for the answer. It is also asked ONCE:
	# `produce_into_for` is handed the result rather than calling back.
	var chosen_color := -1
	if ability.color_options.is_valid():
		var offered: Array = ability.color_options.call(self, inst)
		if not offered.is_empty():
			var color_q := _cost_question(pid, inst, PlayerChoice.Kind.COLOR,
				PlayerChoice.mana_color_prompt(inst.data.card_name))
			color_q.colors.assign(offered)
			if _hold_cost_choice(color_q, replay):
				return ""
			chosen_color = _ask_cost_color(pid, inst, offered, color_q.prompt)
	# "Remove ANY NUMBER of charge counters" (the mana batteries): HOW MANY
	# is the activating player's call, made with the rest of the activation
	# (CR 601.2b) — `@MANABATTERY` (prompts.txt:566) is the original's own
	# question. Nothing to ask with no counters on; zero is a legal answer.
	var counters_spent := 0
	if ability.any_number_counter_kind != "":
		var have: int = int(inst.counters.get(ability.any_number_counter_kind, 0))
		if have > 0:
			var labels: Array[String] = []
			for n in have + 1:
				labels.append(str(n))
			var count_q := _cost_question(pid, inst, PlayerChoice.Kind.OPTION,
				"How many counters do you wish to spend for additional mana? (max: %d)"
				% have)
			count_q.options = labels
			count_q.hint = have
			if _hold_cost_choice(count_q, replay):
				return ""
			counters_spent = _ask_cost_option(pid, inst, labels, count_q.prompt, have)
	if ability.cost != null:
		players[pid].mana_pool.pay(ability.cost)
	if ability.counter_cost_kind != "":
		var left: int = int(inst.counters.get(ability.counter_cost_kind, 0)) \
			- ability.counter_cost_count
		_rec(inst, &"counters")
		if left <= 0:
			inst.counters.erase(ability.counter_cost_kind)
		else:
			inst.counters[ability.counter_cost_kind] = left
	if counters_spent > 0:
		var kind := ability.any_number_counter_kind
		var kept: int = int(inst.counters.get(kind, 0)) - counters_spent
		_rec(inst, &"counters")
		if kept <= 0:
			inst.counters.erase(kind)
		else:
			inst.counters[kind] = kept
	var bonus: int = counters_spent * ability.bonus_per_counter
	if ability.life_cost > 0:
		adjust_life(pid, -ability.life_cost)
	if ability.taps_source:
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = true
	# What this activation actually made — Mana Flare's bonus must match the
	# colour a dynamic source produced, not the seed colour it was built
	# with. Captured BEFORE any side effect can reroll it (Gem Bazaar).
	var produced_color: int = ability.produces[0][0]
	if chosen_color != -1:
		produced_color = chosen_color
	elif ability.dynamic_color.is_valid():
		produced_color = int(ability.dynamic_color.call(self, inst))
	# "Until end of turn, if you tap a land you control for mana, it produces
	# {U} instead of any other type" (Deep Water). The AMOUNT is whatever
	# the ability would have made, so the production runs into a scratch
	# pool and only its total crosses over — which keeps this working for
	# dynamic amounts (the Urzatron) without knowing how they are computed.
	var recolor: int = players[pid].land_mana_becomes
	# EVERY type this activation made, for "one mana of any type that land
	# produced" (Mana Flare): the first colour as it came out above, plus
	# any later literal entry — a two-type ability lets the Flare's player
	# choose (Duel.hlp, Mana Flare). `color` stays the first, for the
	# mono-producing lands that are the whole pool.
	var produced_types: Array = [produced_color]
	if recolor != 0 and inst.is_land() and not ability.scales_with_sacrifice_mv:
		var scratch := ManaPool.new()
		ability.produce_into_for(scratch, self, inst, chosen_color, bonus)
		players[pid].mana_pool.add(recolor, scratch.total())
		produced_color = recolor
		produced_types = [recolor]
	elif ability.scales_with_sacrifice_mv and mana_sacrifice != null:
		var scaled: int = mana_sacrifice.data.cost.mana_value()
		if ability.restriction_key == "":
			players[pid].mana_pool.add(ability.produces[0][0], scaled)
		else:
			players[pid].mana_pool.add_restricted(
				ability.produces[0][0], scaled, ability.restriction_key)
	else:
		ability.produce_into_for(players[pid].mana_pool, self, inst, chosen_color, bonus)
		for i in range(1, ability.produces.size()):
			var extra: int = int(ability.produces[i][0])
			if int(ability.produces[i][1]) > 0 and not produced_types.has(extra):
				produced_types.append(extra)
	if mana_sacrifice != null:
		sacrifice_permanent(mana_sacrifice)
	if ability.side_effect.is_valid():
		ability.side_effect.call(self, inst, pid)
	# Mana triggers (Mana Flare, Wild Growth) fire off-stack right now.
	if inst.is_land() and ability.taps_source:
		dispatch_event(Mtg.EventType.TAPPED_FOR_MANA,
			{"instance": inst, "controller": pid, "color": produced_color,
				"colors": produced_types})
	# "Becomes tapped" triggers (City of Brass) — normal stacked triggers.
	if ability.taps_source:
		dispatch_event(Mtg.EventType.BECAME_TAPPED,
			{"instance": inst, "controller": pid})
	# CR 605.1a: a mana ability is still an ACTIVATED ability, so "whenever
	# a player activates an ability of ..." hears one (Artifact Possession,
	# Powerleech and Haunting Wind all watch artifacts, and Ashnod's Altar
	# is an artifact whose mana ability costs a sacrifice, not a tap). The
	# listener check is the hot-path guard Mtg.EventType.ABILITY_ACTIVATED
	# documents — this runs for every land, every turn.
	if has_trigger_listener(Mtg.EventType.ABILITY_ACTIVATED):
		dispatch_event(Mtg.EventType.ABILITY_ACTIVATED, {
			"instance": inst, "controller": inst.controller_id, "player": pid,
			"ability": ability, "index": ability_index,
			"taps": ability.taps_source,
			"stack_id": -1,   # a mana ability never uses the stack
		})
	if ability.sacrifice_source:
		# "{T}, Sacrifice ...:" — the mana is already in the pool; the
		# permanent goes to the graveyard as part of the cost (Black Lotus).
		sacrifice_permanent(inst)
	else:
		_recalculate_for_tap_change()
	# A mana ability is an activated ability, so its activator receives
	# priority afterward (CR 117.3c) — the moment a trigger the tap fired
	# (Relic Bind's "whenever enchanted artifact becomes tapped") is put on
	# the stack and its controller names its target (CR 603.3d). A human
	# seat's question holds the duel open here; priority does not move.
	if _hold_trigger_targets(priority_player):
		return ""
	_emit_state()
	return ""


## Is [param pid] forbidden to cast or play [param data] right now? ""
## when it is legal, else the banning permanent's name (City in a Bottle).
## "Until that player's next turn, that player plays with that card
## revealed in their hand and can't play it" (Firestorm Phoenix): stamp
## the card now in its owner's hand. Lifted by [method _end_turn] as its
## owner's next turn begins; wiped early if the card leaves the hand (the
## CardInstance `zone` setter — CR 400.7).
func _lock_in_hand(inst: CardInstance) -> void:
	if undo_log != null:
		_rec(inst, &"hand_lock_turn")
		_rec(inst, &"revealed_in_hand")
	inst.hand_lock_turn = turn_number
	inst.revealed_in_hand = true
	log_line("%s is revealed in %s's hand and can't be played until their next turn" % [
		inst.data.card_name, players[inst.owner_id].player_name])


## Why [param inst] may not be played from the hand it sits in right now
## (the Firestorm Phoenix lock), or "".
func hand_lock_reason(inst: CardInstance) -> String:
	if inst.zone == Mtg.Zone.HAND and inst.hand_lock_turn != -1:
		return "%s can't be played until your next turn" % inst.data.card_name
	return ""


## Lift every hand lock of [param pid]'s that was stamped on an earlier
## turn — "until your next turn" ends as that turn begins.
func _release_hand_locks(pid: int) -> void:
	for inst in players[pid].hand:
		if inst.hand_lock_turn == -1 or inst.hand_lock_turn == turn_number:
			continue
		if undo_log != null:
			_rec(inst, &"hand_lock_turn")
			_rec(inst, &"revealed_in_hand")
		inst.hand_lock_turn = -1
		inst.revealed_in_hand = false
		log_line("%s may be played again" % inst.data.card_name)


func play_banned(pid: int, data: CardData) -> String:
	for inst in all_battlefield():
		if not inst.data.play_ban.is_valid():
			continue
		if bool(inst.data.play_ban.call(self, pid, data)):
			return inst.data.card_name
	return ""


## The RESTRICTION KEYS a spell qualifies for — which restricted mana
## ("spend this mana only to cast artifact spells") may pay for it.
func mana_usage_keys(data: CardData) -> Array:
	var keys: Array = []
	if data.is_type(Mtg.CardType.ARTIFACT):
		keys.append("artifact")
	if data.is_creature():
		keys.append("creature")
	return keys


# ============================ the X a spell is being cast for, and the DRY RUN --
#
# WHY THIS EXISTS. "Target artifact with mana value X" (Detonate) and
# "target spell with mana value X" (Spell Blast) are TARGETING
# restrictions (CR 115.4): the X is part of the spell's identity while it
# is being cast, so a target's legality cannot be answered without one.
# The X used to reach those filters exactly one way — [method cast_spell]
# stamping `memory["x_value"]` on its way past — which meant nobody could
# ask the question BEFORE announcing the spell. A planner that has to pay
# to find out is a planner that leaks mana: it taps its lands, the engine
# rules the target illegal, and the mana is gone (the AI did exactly that
# on Fire and Brimstone, Detonate and Orcish Catapult — docs/ROADMAP.md,
# "The AI block audit and dead-card sweep", class 4).
#
# The seam is two halves, and both are read-only:
#
#   * [method casting_x] is the ONE reader a card's filter uses. It
#     answers "what X is this card being cast for?" with the value a
#     planner has PROPOSED while trying an X on, and with the stamped one
#     otherwise — so the same filter gives the same answer at plan time,
#     at announcement and at resolution.
#   * [method cast_refusal] is [method cast_spell]'s whole validation half
#     run as a DRY RUN: same code, nothing paid, nothing moved, no roll
#     consumed, no question asked. `cast_spell` calls it too, so the two
#     can never drift.
#
# The proposal is scoped to one question and never observable outside it,
# so it needs no undo record and no snapshot entry: every push is matched
# by its pop inside the same synchronous call.

## Instance id -> the X a planner is currently TRYING ON for that card.
## Transient by construction (see the block comment above): pushed and
## popped around a single query, never left set between actions.
var _proposed_x: Dictionary = {}


## The X [param inst] is being cast for, as the game understands it right
## now: the value a planner has proposed while trying an X on, else the
## value [method cast_spell] stamped. A card whose TARGETING restriction
## reads its own X ("... with mana value X") must ask this and not
## `memory` directly, or it can only be asked after the mana is spent.
func casting_x(inst: CardInstance) -> int:
	if inst == null:
		return 0
	if _proposed_x.has(inst.id):
		return int(_proposed_x[inst.id])
	return int(inst.memory.get("x_value", 0))


## Start proposing X = [param x] for [param inst]; returns what to hand
## [method _pop_proposed_x] to undo it (-1 = there was no proposal).
func _push_proposed_x(inst: CardInstance, x: int) -> int:
	if inst == null:
		return -1
	var was: int = int(_proposed_x.get(inst.id, -1))
	_proposed_x[inst.id] = maxi(x, 0)
	return was


func _pop_proposed_x(inst: CardInstance, was: int) -> void:
	if inst == null:
		return
	if was < 0:
		_proposed_x.erase(inst.id)
	else:
		_proposed_x[inst.id] = was


## Is [param ref] a legal target for [param spec] if [param source] were
## cast for X = [param x_value]? The prospective twin of
## [method TargetSpec.is_legal] — see the block comment above.
func target_legal_at(spec: TargetSpec, ref: TargetRef, source: CardInstance,
		x_value: int, earlier: Array = []) -> bool:
	var was := _push_proposed_x(source, x_value)
	var ok := spec.is_legal(self, ref, source, earlier)
	_pop_proposed_x(source, was)
	return ok


## Every legal target for [param spec] if [param source] were cast for
## X = [param x_value]. The prospective twin of
## [method TargetSpec.legal_targets].
func legal_targets_at(spec: TargetSpec, source: CardInstance, x_value: int,
		earlier: Array = []) -> Array[TargetRef]:
	var was := _push_proposed_x(source, x_value)
	var out := spec.legal_targets(self, source, earlier)
	_pop_proposed_x(source, was)
	return out


## Would [method cast_spell] refuse this announcement, and why? Everything
## it checks that can be answered without paying: the zone, priority and
## timing gates, the mode, the damage window, the whole target plan at
## THIS X (legality, the no-duplicate rule, the divided arithmetic, the
## arity a rolled or opponent-chosen slot demands) and the additional
## sacrifice cost. "" means only the mana is left to find.
##
## It is deliberately the SAME code the real cast runs, so a planner that
## asks first can never be surprised by an answer it did not mirror.
func cast_refusal(pid: int, inst: CardInstance, targets: Array = [],
		x_value := 0, mode := 0) -> String:
	return String(_cast_checks(pid, inst, targets, x_value, mode)["error"])


## The validation half of [method cast_spell]: `{error, plan, bodies}`.
## Pays nothing, moves nothing, rolls nothing and asks nothing — the rolls
## (CR 601.2c) and the cost questions come after every refusal, in
## `cast_spell` itself.
func _cast_checks(pid: int, inst: CardInstance, targets: Array,
		x_value: int, mode: int) -> Dictionary:
	var no_bodies: Array[CardInstance] = []
	var out := {"error": "", "plan": null, "bodies": no_bodies}
	var err := _act_precheck(pid)
	if err != "":
		out["error"] = err
		return out
	if priority_player != pid:
		out["error"] = "you don't have priority"
		return out
	if inst.zone != Mtg.Zone.HAND or inst.owner_id != pid:
		out["error"] = "%s is not in your hand" % inst.data.card_name
		return out
	var locked_why := hand_lock_reason(inst)
	if locked_why != "":
		out["error"] = locked_why
		return out
	if inst.is_land():
		out["error"] = "lands are played, not cast"
		return out
	var banned_by := play_banned(pid, inst.data)
	if banned_by != "":
		out["error"] = "%s can't be cast (%s)" % [inst.data.card_name, banned_by]
		return out
	if not inst.is_type(Mtg.CardType.INSTANT):
		if pid != active_player or not Mtg.is_main_step(current_step()) or not stack.is_empty():
			out["error"] = "%s can only be cast in your main phase with an empty stack" \
				% inst.data.card_name
			return out
	# "Cast this spell only ..." timing riders (Reset, Berserk, Teleport).
	if inst.data.cast_condition.is_valid():
		var when_why: String = inst.data.cast_condition.call(self, pid)
		if when_why != "":
			out["error"] = when_why
			return out
	# --- mode (modal spells: chosen while casting, CR 601.2b / 700.2) ---
	if inst.data.is_modal():
		if mode < 0 or mode >= inst.data.modes.size():
			out["error"] = "%s has no mode %d" % [inst.data.card_name, mode]
			return out
	else:
		mode = 0
	# THE DAMAGE-PREVENTION WINDOW (§6.8) is a restricted ALLOW, and the
	# MODE decides: Healing Salve's second mode is a prevention effect and
	# its first one is not, which is exactly what `Duel.hlp` says of it
	# ("It may only be played in this way during damage prevention").
	var window_why := _damage_window_refusal(
		inst.data.modes[mode]["effects"] if inst.data.is_modal()
		else inst.data.spell_effects)
	if window_why != "":
		out["error"] = window_why
		return out
	# --- targets ---
	# TargetPlan groups the flat ref list per targeting effect (variable
	# counts, divided amounts) and checks legality, the no-duplicate rule
	# and the division arithmetic in one place — CR 601.2c/d. The whole
	# group is judged with X PROPOSED, so a spec that reads it ("target
	# artifact with mana value X") gets the same answer here as it will
	# when the spell is really announced.
	if inst.data.cost.has_x and x_value < 0:
		out["error"] = "X must be 0 or more"
		return out
	var was := _push_proposed_x(inst, x_value)
	var plan := TargetPlan.for_spell(self, inst.data, mode, targets, x_value, inst)
	var target_why := plan.error
	if target_why == "":
		target_why = _adverse_targets_refusal(plan, inst)
	if target_why == "":
		target_why = _random_targets_refusal(plan, inst)
	_pop_proposed_x(inst, was)
	if target_why != "":
		out["error"] = target_why
		return out
	out["plan"] = plan
	# ADDITIONAL COSTS: "as an additional cost, sacrifice a creature"
	# (Metamorphosis) needs a legal body BEFORE any mana is spent. Only the
	# LEGALITY is settled here — WHICH body goes is asked in `cast_spell`,
	# once no refusal is left (CR 601.2h: a refused cast leaves everything
	# as it was, and the choice ledger is part of "everything").
	if not inst.data.additional_sacrifice.is_empty():
		var want: Dictionary = inst.data.additional_sacrifice
		var extra_bodies: Array[CardInstance] = []
		for perm in players[pid].battlefield:
			if want["filter"].call(perm):
				extra_bodies.append(perm)
		if extra_bodies.is_empty():
			out["error"] = "no %s to sacrifice" % String(want["desc"])
			return out
		out["bodies"] = extra_bodies
	return out


## Cast a spell from hand. [param targets] holds one TargetRef per
## targeting effect of the card, in effect order (auras: exactly one — the
## permanent to enchant). Mana must already be floating (tap_for_mana
## first); the cost is paid here. [param mode] picks a mode of a modal
## ("Choose one —") spell; non-modal spells ignore it.
func cast_spell(pid: int, inst: CardInstance, targets: Array = [], x_value := 0,
		mode := 0) -> String:
	_begin_cost_choices()
	var checks := _cast_checks(pid, inst, targets, x_value, mode)
	if String(checks["error"]) != "":
		return String(checks["error"])
	if inst.data.is_modal():
		mode = clampi(mode, 0, inst.data.modes.size() - 1)
	else:
		mode = 0
	# The chosen X is stamped on the card now that nothing above can refuse
	# the cast (CR 601.2h — a refused announcement leaves everything as it
	# was). Its targets were validated at exactly this X a moment ago, by
	# the PROPOSAL the checks ran under; the stamp is what carries the same
	# answer forward to the rolls below, to resolution, and to a permanent
	# that "enters with X counters" (Frankenstein's Monster, Rock Hydra).
	if inst.data.cost.has_x:
		_rec(inst, &"memory")
		inst.memory["x_value"] = x_value
	var plan: TargetPlan = checks["plan"]
	var extra_bodies: Array[CardInstance] = checks["bodies"]
	var extra_sacrifice: CardInstance = null
	# --- cost (base + cost-modifier surcharges, CR 601.2f) ---
	# Cost modifiers may REDUCE (Mana Matrix, Planar Gate, Stone Calendar);
	# a reduction can never eat into the coloured part of the cost, so the
	# surcharge is clamped at minus the printed generic (CR 601.2f).
	# {X}{X}{U} (Part Water) charges the chosen X once per printed {X}. X is
	# part of the total cost BEFORE reductions apply (CR 601.2f), so the
	# discount floor is the printed generic PLUS what X contributed — a
	# Mana Matrix really does make a Howl from Beyond for X=3 cost {1}{B}.
	# "Spend only black mana on X" (Drain Life) pays X as COLOURED pips
	# instead, which no generic reduction may eat (CR 601.2f).
	# "Costs {1} more for each target beyond the first" (Fireball) is part
	# of it and is priced only once the target group is known. Restricted
	# mana ("spend this only to cast artifact spells"), colour
	# substitutions (Sunglasses of Urza) and North Star's any-type charge
	# all widen what this pool can cover (CR 106.6).
	var payment := spell_payment(pid, inst.data, x_value, plan.count())
	var pay_cost: ManaCost = payment["cost"]
	var pay_extra: int = payment["extra"]
	var surcharge: int = payment["surcharge"]
	var usage: Array = payment["usage"]
	var subs: Array = players[pid].mana_substitutions
	var pool := players[pid].mana_pool
	var wildcard := false
	if not pool.can_pay(pay_cost, pay_extra, usage, subs):
		if players[pid].any_color_spells > 0 \
				and pool.can_pay(pay_cost, pay_extra, usage, subs, true):
			wildcard = true
		elif surcharge > 0:
			return "not enough mana for %s (%s plus {%d} more)" % [
				inst.data.card_name, inst.data.cost.text, surcharge]
		else:
			return "not enough mana for %s (%s)" % [
				inst.data.card_name, inst.data.cost.text]
	# THE COST IS PAYABLE — from here nothing can refuse, so this is where
	# the seat is asked which body the additional cost eats. Asking earlier
	# filed a PlayerChoice (and a "(decided for …)" log line) for a cast the
	# engine then turned down. An opponent's own target comes first (CR
	# 601.2c) — no spell in the pool has one, but the plan carries the slot.
	if not _fill_adverse_targets(plan, pid, inst, {"kind": "cast", "pid": pid,
			"inst": inst, "targets": targets, "x": x_value, "mode": mode}):
		return ""
	if not extra_bodies.is_empty():
		var want2: Dictionary = inst.data.additional_sacrifice
		var body_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
			PlayerChoice.sacrifice_prompt(String(want2["desc"])))
		body_q.candidates = extra_bodies
		# Nothing below refuses and nothing above mutated, so the question
		# can HOLD THE WHOLE CAST OPEN on a record of this call
		# (docs/duel-todo.md §1.3) — the spell is not on the stack yet, so
		# there is nothing for the pre-flight to probe.
		if _hold_cost_choice(body_q, {"kind": "cast", "pid": pid, "inst": inst,
				"targets": targets, "x": x_value, "mode": mode}):
			return ""
		extra_sacrifice = _ask_cost_card(pid, inst, extra_bodies, body_q.prompt)
	# Every question is answered and nothing can refuse: the game rolls
	# the targets that are its to roll (CR 601.2c, before the cost of
	# 601.2h) — once, since a held cast reaches here only on its replay.
	_fill_random_targets(plan, inst)
	if wildcard:
		players[pid].any_color_spells -= 1
		log_line("%s spends mana as though it were any type (North Star)"
			% players[pid].player_name)
	pool.pay(pay_cost, pay_extra, usage, subs, wildcard)
	# --- to the stack ---
	if extra_sacrifice != null:
		# The spell remembers what it ate — Metamorphosis' X reads it.
		_rec(inst, &"memory")
		inst.memory["sacrificed_mv"] = extra_sacrifice.data.cost.mana_value()
		sacrifice_permanent(extra_sacrifice)
	if undo_log != null:
		_rec(players[pid], &"hand")
		_rec(inst, &"zone")
	players[pid].hand.erase(inst)
	inst.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = inst
	item.controller = pid
	item.mode = mode
	if inst.data.is_modal():
		var mode_effects: Array[EffectBase] = []
		for e in inst.data.modes[mode]["effects"]:
			mode_effects.append(e)
		item.effects = mode_effects
	else:
		item.effects = inst.data.spell_effects
	# The plan's refs (not the raw list): a divided effect with one chosen
	# target has had the whole total folded into that ref by now.
	for t in plan.flat():
		item.targets.append(t)
	item.target_groups = plan.groups
	item.x_value = x_value
	# (memory["x_value"] was stamped above, before target validation — the
	# permanent this becomes reads it for "enters with X counters".)
	# SIMPLIFIED: the description names the caster and the card and no
	# more. s30's is `"<controller> casts <name>[ for N][ targeting A,
	# B]"`, and this string is the game LOG's sentence as well as the
	# chain window's tooltip, so filling in the targets and the chosen X
	# would improve both at once. `docs/duel-todo.md` §3.9 and
	# `docs/ROADMAP.md` carry it.
	item.description = "%s casts %s" % [players[pid].player_name, inst.data.card_name]
	if undo_log != null:
		_rec(self, &"stack")
		_rec(self, &"_next_stack_id")
		_rec(self, &"spells_cast_this_turn")
		_rec(players[pid], &"acted_this_turn")
		_rec(self, &"priority_player")
		_rec(self, &"_passes")
	item.id = _next_stack_id
	_next_stack_id += 1
	stack.append(item)
	spells_cast_this_turn[pid].append(inst.data)
	# Arboria: "cast a spell ... during their last turn" — only what a
	# player does on their OWN turn counts.
	if pid == active_player:
		players[pid].acted_this_turn = true
	# "When you cast this spell, ..." (Mana Vortex): the spell itself, on
	# the stack, is a listener for its own cast event — offered only when
	# its printed triggers include one, so the common cast keeps the
	# dispatcher's fast path.
	var self_listener: CardInstance = null
	for trig in inst.data.triggered_abilities:
		if trig.event_type == Mtg.EventType.SPELL_CAST:
			self_listener = inst
			break
	dispatch_event(Mtg.EventType.SPELL_CAST, {"instance": inst, "controller": pid},
		self_listener)
	log_line(item.description)
	# Caster keeps priority after casting (CR 117.3c).
	_resume_priority(pid)
	return ""


## Activate a (non-mana) activated ability of a battlefield permanent.
func activate_ability(pid: int, inst: CardInstance, index: int, targets: Array = [],
		x_value := 0) -> String:
	_begin_cost_choices()
	var err := _act_precheck(pid)
	if err != "":
		return err
	if priority_player != pid:
		return "you don't have priority"
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return "that permanent isn't on the battlefield"
	# LIVE abilities: statics may have granted extras (Zombie Master).
	if index < 0 or index >= inst.cur_activated_abilities.size():
		return "no such ability"
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	# Normally only the controller may activate; Clergy of the Holy
	# Nimbus hands one ability to the opponents instead.
	if ability.any_player_may_activate:
		pass   # anybody may activate it
	elif ability.only_owner_may_activate:
		# "Only this creature's owner may activate this ability" (Personal
		# Incarnation) — OWNER, not controller, so a stolen Incarnation
		# still answers to the player whose card it is.
		if inst.owner_id != pid:
			return "only its owner may activate that ability"
	elif ability.only_opponents_may_activate:
		if inst.controller_id == pid:
			return "only your opponents may activate that ability"
	elif inst.controller_id != pid:
		return "you don't control that permanent"
	var ability_window_why := _damage_window_refusal(ability.effects)
	if ability_window_why != "":
		return ability_window_why
	if ability.only_during_combat and not Mtg.is_combat_step(current_step()):
		return "activate only during combat"
	if ability.only_during_step >= 0 and current_step() != ability.only_during_step:
		return "activate only during the %s step" % \
			Mtg.step_name(ability.only_during_step).to_lower()
	if ability.only_before_step >= 0 \
			and Mtg.STEP_ORDER.find(current_step()) \
				>= Mtg.STEP_ORDER.find(ability.only_before_step):
		return "activate only before the %s step" % \
			Mtg.step_name(ability.only_before_step).to_lower()
	if ability.activation_condition.is_valid():
		var why: String = ability.activation_condition.call(self, inst)
		if why != "":
			return why
	if ability.turn_restriction > 0 and pid != active_player:
		return "activate only during your turn"
	if ability.turn_restriction < 0 and pid == active_player:
		return "activate only during an opponent's turn"
	if ability.max_per_turn > 0 \
			and int(inst.ability_uses.get(index, 0)) >= ability.max_per_turn:
		return "activate only %s each turn" % (
			"once" if ability.max_per_turn == 1 else "%d times" % ability.max_per_turn)
	# "Sacrifice a <filter>" costs need a legal body BEFORE anything is paid.
	# LEGALITY only: which body goes is asked below, once nothing can refuse
	# (CR 601.2h — see cast_spell for the same split).
	var sacrifice_bodies: Array[CardInstance] = []
	var sacrifice_pick: CardInstance = null
	if ability.sacrifice_filter.is_valid():
		for perm in players[pid].battlefield:
			if (perm != inst or ability.sacrifice_may_be_source) \
					and ability.sacrifice_filter.call(perm):
				sacrifice_bodies.append(perm)
		# The SOURCE goes last (Fallen Angel): the funnel's callers pre-sort
		# by desirability, and eating the permanent whose ability you are
		# paying for is never the answer while any other body is on offer.
		if ability.sacrifice_may_be_source and sacrifice_bodies.size() > 1 \
				and sacrifice_bodies.has(inst):
			sacrifice_bodies.erase(inst)
			sacrifice_bodies.append(inst)
		if sacrifice_bodies.is_empty() and not ability.sacrifice_any_number:
			return "no %s to sacrifice" % ability.sacrifice_filter_desc
	# "Exile a <something> you control" — same split (City of Shadows).
	var exile_bodies: Array[CardInstance] = []
	var exile_pick: CardInstance = null
	if ability.exile_filter.is_valid():
		for perm in players[pid].battlefield:
			if perm != inst and ability.exile_filter.call(perm):
				exile_bodies.append(perm)
		if exile_bodies.is_empty():
			return "no %s to exile" % ability.exile_filter_desc
	# "Exile a <something> from your graveyard" — same split as above:
	# legality now, WHICH card once nothing can refuse (Necropolis).
	var grave_bodies: Array[CardInstance] = []
	var grave_pick: CardInstance = null
	if ability.graveyard_exile_filter.is_valid():
		for buried in players[pid].graveyard:
			if ability.graveyard_exile_filter.call(buried):
				grave_bodies.append(buried)
		if grave_bodies.is_empty():
			return "no %s in your graveyard to exile" % ability.graveyard_exile_desc
	if ability.tap_cost:
		if inst.tapped:
			return "%s is already tapped" % inst.data.card_name
		if inst.is_creature() and inst.summoning_sick \
				and not inst.has_keyword(Mtg.Keyword.HASTE):
			return "summoning sickness (CR 602.5g)"
	if ability.cost.has_x and x_value < 0:
		return "X must be 0 or more"
	if ability.min_x > 0 and x_value < ability.min_x:
		return "X can't be less than %d" % ability.min_x
	if ability.x_condition.is_valid():
		var x_why: String = ability.x_condition.call(self, inst, x_value, targets)
		if x_why != "":
			return x_why
	var plan := TargetPlan.for_ability(self, ability, targets, x_value, inst)
	if plan.error != "":
		return plan.error
	var adverse_why := _adverse_targets_refusal(plan, inst)
	if adverse_why != "":
		return adverse_why
	var random_why := _random_targets_refusal(plan, inst)
	if random_why != "":
		return random_why
	# "Pay {R} for each target" (Goblin Polka Band) pays X in COLOUR; every
	# other {X} ability pays it as generic (CR 601.2f).
	var payment := ability_payment(pid, inst, index, x_value)
	var pay_cost: ManaCost = payment["cost"]
	var surcharge: int = payment["extra"]
	# Abilities never qualify for "spend this only to CAST ..." mana, but
	# colour substitutions apply to every payment.
	var ability_subs: Array = players[pid].mana_substitutions
	if not players[pid].mana_pool.can_pay(pay_cost, surcharge, [], ability_subs):
		if surcharge > 0:
			return "not enough mana (%s plus {%d} more)" % [ability.cost.text, surcharge]
		return "not enough mana (%s)" % ability.cost.text
	if ability.life_cost > 0 and players[pid].life < ability.life_cost:
		return "not enough life to pay %d" % ability.life_cost
	if ability.random_discard_cost > 0 \
			and players[pid].hand.size() < ability.random_discard_cost:
		return "not enough cards in hand to discard"
	if ability.discard_cost > 0 and players[pid].hand.size() < ability.discard_cost:
		return "not enough cards in hand to discard"
	if ability.discard_last_drawn_cost:
		# "Discard the last card you drew this turn" names ONE specific card
		# (CR 601.2g): none drawn, nothing to discard; drawn but gone from
		# the hand since, nothing to discard either.
		if players[pid].drawn_this_turn.is_empty():
			return "you haven't drawn a card this turn"
		if not players[pid].hand.has(players[pid].drawn_this_turn[-1]):
			return "the last card you drew this turn is no longer in your hand"
	if ability.counter_cost_kind != "" \
			and int(inst.counters.get(ability.counter_cost_kind, 0)) \
				< ability.counter_cost_count:
		return "not enough %s counters to remove" % ability.counter_cost_kind
	# THE COST IS PAYABLE — nothing below refuses, so this is where the seat
	# picks the body its sacrifice cost eats — and, first, where an OPPONENT
	# names the target that is theirs to choose (CR 601.2c: targets are
	# chosen before costs are paid).
	if not _fill_adverse_targets(plan, pid, inst, {"kind": "activate",
			"pid": pid, "inst": inst, "index": index, "targets": targets,
			"x": x_value}):
		return ""
	var sacrifice_picks: Array[CardInstance] = []
	if ability.sacrifice_any_number:
		# "Sacrifice any number of <desc>" (Sword of the Ages): one optional
		# question per body, until the payer declines or runs out. Each is
		# its own cost question, so a human seat is held on every one and
		# the replay serves each answer in turn (see [member _cost_values]).
		var left: Array[CardInstance] = sacrifice_bodies.duplicate()
		while not left.is_empty():
			var more_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
				"Sacrifice a %s? (%d chosen so far)" % [
					ability.sacrifice_filter_desc, sacrifice_picks.size()])
			more_q.candidates = left
			more_q.optional = true
			if _hold_cost_choice(more_q, {"kind": "activate", "pid": pid,
					"inst": inst, "index": index, "targets": targets,
					"x": x_value}):
				return ""
			var one := _ask_cost_card_optional(pid, inst, left, more_q.prompt)
			if one == null:
				break
			sacrifice_picks.append(one)
			left.erase(one)
	elif not sacrifice_bodies.is_empty():
		var body_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
			PlayerChoice.sacrifice_prompt(ability.sacrifice_filter_desc))
		body_q.candidates = sacrifice_bodies
		# As in cast_spell: no refusal left, nothing mutated, so the
		# question holds the activation open on a record of this call
		# (docs/duel-todo.md §1.3).
		if _hold_cost_choice(body_q, {"kind": "activate", "pid": pid,
				"inst": inst, "index": index, "targets": targets,
				"x": x_value}):
			return ""
		sacrifice_pick = _ask_cost_card(pid, inst, sacrifice_bodies,
			body_q.prompt)
	if not exile_bodies.is_empty():
		var exile_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
			"Exile a %s" % ability.exile_filter_desc)
		exile_q.candidates = exile_bodies
		if _hold_cost_choice(exile_q, {"kind": "activate", "pid": pid,
				"inst": inst, "index": index, "targets": targets,
				"x": x_value}):
			return ""
		exile_pick = _ask_cost_card(pid, inst, exile_bodies, exile_q.prompt)
	if not grave_bodies.is_empty():
		var grave_q := _cost_question(pid, inst, PlayerChoice.Kind.CARD,
			"Exile a %s from your graveyard" % ability.graveyard_exile_desc)
		grave_q.candidates = grave_bodies
		if _hold_cost_choice(grave_q, {"kind": "activate", "pid": pid,
				"inst": inst, "index": index, "targets": targets,
				"x": x_value}):
			return ""
		grave_pick = _ask_cost_card(pid, inst, grave_bodies, grave_q.prompt)
	# Every question is answered and nothing can refuse: the game rolls
	# the targets that are its to roll (CR 601.2c — so the Polka Band's
	# own untapped body is a candidate, its {T} not yet paid) — once.
	_fill_random_targets(plan, inst)
	# Pay costs (not undoable, CR 601.2h).
	players[pid].mana_pool.pay(pay_cost, surcharge, [], ability_subs)
	if ability.counter_cost_kind != "":
		# Counters come off NOW, so a second activation in response cannot
		# spend the same ones (Triskelion, Osai Vultures, Scavenging Ghoul).
		var left: int = int(inst.counters.get(ability.counter_cost_kind, 0)) \
			- ability.counter_cost_count
		if left <= 0:
			_rec(inst, &"counters")
			inst.counters.erase(ability.counter_cost_kind)
		else:
			_rec(inst, &"counters")
			inst.counters[ability.counter_cost_kind] = left
		log_line("%s removes %d %s counter(s)" % [
			inst.data.card_name, ability.counter_cost_count, ability.counter_cost_kind])
		recalculate()
	if ability.max_per_turn > 0:
		_rec(inst, &"ability_uses")
		inst.ability_uses[index] = int(inst.ability_uses.get(index, 0)) + 1
	if ability.tap_cost:
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = true
		dispatch_event(Mtg.EventType.BECAME_TAPPED,
			{"instance": inst, "controller": pid})
	if ability.life_cost > 0:
		adjust_life(pid, -ability.life_cost)
	if ability.random_discard_cost > 0:
		discard_random(pid, ability.random_discard_cost, false)
	# WHAT THE COST ATE, collected for THIS activation and handed to the
	# StackItem below — never written onto the permanent, which has one
	# slot and would let two stacked activations read each other's record.
	# See [member StackItem.cost_paid] for the bug that taught us.
	var cost_record := {}
	if ability.discard_cost > 0:
		# The chooser is the PAYING player, and what went is recorded for
		# the ability's effects to read (Land's Edge).
		var thrown := _ask_cost_discard(pid, inst, ability.discard_cost)
		if not thrown.is_empty():
			cost_record["_discarded_types"] = thrown[0].data.types
			cost_record["_discarded_name"] = thrown[0].data.card_name
		discard_cards(pid, thrown, false)
	if ability.discard_last_drawn_cost:
		# The card itself, checked payable above; a COST discard, so
		# Library of Leng has no say in where it goes (CR 701.8a, and the
		# 1997 help's own ruling on the Library).
		var last_drawn: CardInstance = players[pid].drawn_this_turn[-1]
		cost_record["_discarded_types"] = last_drawn.data.types
		cost_record["_discarded_name"] = last_drawn.data.card_name
		discard_cards(pid, [last_drawn], false)
	if sacrifice_pick != null:
		# Record what the cost ate so the ability's OWN effects can read it
		# on resolution ("You gain life equal to the sacrificed creature's
		# toughness" — Diamond Valley, Life Chisel). The values are last
		# known information (CR 608.2h), snapshotted while the body is
		# still on the battlefield.
		cost_record["_sacrificed_power"] = sacrifice_pick.cur_power
		cost_record["_sacrificed_toughness"] = sacrifice_pick.cur_toughness
		sacrifice_permanent(sacrifice_pick)
	if not sacrifice_picks.is_empty():
		# "Any number of" — the whole set, with its total power snapshotted
		# while the bodies still stand (CR 608.2h), and the instances kept
		# so the ability can find the cards they left behind (Sword of the
		# Ages exiles them).
		var names := PackedStringArray()
		var total_power := 0
		for body in sacrifice_picks:
			names.append(body.data.card_name)
			total_power += maxi(body.cur_power, 0)
		cost_record["_sacrificed_names"] = names
		cost_record["_sacrificed_total_power"] = total_power
		cost_record["_sacrificed_instances"] = sacrifice_picks
		for body in sacrifice_picks:
			sacrifice_permanent(body)
	if exile_pick != null:
		cost_record["_exiled_mana_value"] = exile_pick.data.cost.mana_value()
		cost_record["_exiled_name"] = exile_pick.data.card_name
		exile_permanent(exile_pick)
	if grave_pick != null:
		# The ability's own effects read what the cost ate, the same way
		# they read a sacrifice cost's body (CR 608.2h last known
		# information, snapshotted before the card leaves the graveyard).
		cost_record["_exiled_mana_value"] = grave_pick.data.cost.mana_value()
		cost_record["_exiled_name"] = grave_pick.data.card_name
		exile_from_graveyard(grave_pick)
	if ability.sacrifice_cost:
		sacrifice_permanent(inst)
	if ability.exile_cost:
		exile_permanent(inst)
	var item := StackItem.new()
	item.kind = Mtg.StackKind.ABILITY
	item.card = inst
	item.controller = pid
	item.effects = ability.effects
	item.x_value = x_value
	item.cost_paid = cost_record
	for t in plan.flat():
		item.targets.append(t)
	item.target_groups = plan.groups
	item.description = "%s activates %s: %s" % [
		players[pid].player_name, inst.data.card_name, ability.text]
	if undo_log != null:
		_rec(self, &"stack")
		_rec(self, &"_next_stack_id")
		_rec(self, &"priority_player")
		_rec(self, &"_passes")
	item.id = _next_stack_id
	_next_stack_id += 1
	stack.append(item)
	log_line(item.description)
	# CR 602.2b — the ability is now ON the stack, so anything that triggers
	# on its activation goes on TOP of it and resolves first (Artifact
	# Possession stings before the Basalt Monolith untaps). Dispatched after
	# the append for exactly that ordering.
	dispatch_event(Mtg.EventType.ABILITY_ACTIVATED, {
		"instance": inst, "controller": inst.controller_id, "player": pid,
		"ability": ability, "index": index, "taps": ability.tap_cost,
		# The ability's own STACK id, so a trigger that fires on the
		# activation can counter exactly it (Imprison). A mana ability
		# never uses the stack (CR 605.3a) and so carries -1.
		"stack_id": item.id,
	})
	# The activator keeps priority afterward (CR 117.3c).
	_resume_priority(pid)
	return ""


## Pass priority. When both players pass in succession the top of the stack
## resolves — or, with an empty stack, the game moves to the next step
## (CR 117.4).
func pass_priority(pid: int) -> String:
	var err := _act_precheck(pid)
	if err != "":
		return err
	if priority_player != pid:
		return "you don't have priority"
	if undo_log != null:
		_rec(self, &"_passes")
		_rec(self, &"priority_player")
	_passes += 1
	if _passes < 2:
		priority_player = opponent_of(pid)
		_emit_state()
		return ""
	# Both passed.
	_passes = 0
	if not stack.is_empty():
		# A prevention effect cast INSIDE the window still resolves inside
		# it — the window is a priority round like any other, and its
		# pools are drawn down when the packets land (§6.8).
		_resolve_top()
	elif awaiting_damage_prevention or awaiting_regeneration:
		_close_damage_window()
	else:
		_advance_step()
	return ""


## Declare attackers (active player, during the declare-attackers step).
## [param attacker_ids] may be empty — that skips combat. [param band_list]
## optionally groups attacker ids into attack bands (Array of Arrays;
## banding legality per CR 702.22c is validated).
func declare_attackers(pid: int, attacker_ids: Array, band_list: Array = []) -> String:
	if game_over:
		return "the game is over"
	if not awaiting_attackers:
		return "not the time to declare attackers"
	if pid != active_player:
		return "only the active player declares attackers"
	if no_attacks_this_turn and not attacker_ids.is_empty():
		return "creatures can't attack this turn"
	# "This creature attacks this turn if able" (Nettling Imp, Siren's Call).
	# CR 508.1d: requirements are obeyed only as far as the RESTRICTIONS
	# allow. A blanket ban (Festival) or an attacker cap (Caverns of
	# Despair) therefore excuses every must-attacker — without this the
	# declare-attackers step could not be left at all and the game hung.
	var attacks_banned := no_attacks_this_turn \
		or (max_attackers > 0 and attacker_ids.size() >= max_attackers)
	for conscript in players[pid].battlefield:
		if attacks_banned or not conscript.must_attack_this_turn \
				or attacker_ids.has(conscript.id):
			continue
		if CombatState.attack_illegality(self, conscript, opponent_of(pid)) == "":
			return "%s must attack this turn if able" % conscript.data.card_name
	var defender := opponent_of(pid)
	var declared: Array[CardInstance] = []
	for id in attacker_ids:
		var inst := find_instance(id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.controller_id != pid:
			return "attacker #%s is not a permanent you control" % str(id)
		var why := CombatState.attack_illegality(self, inst, defender)
		if why != "":
			return "%s can't attack: %s" % [inst.data.card_name, why]
		declared.append(inst)
	for band in band_list:
		for id in band:
			if not attacker_ids.has(id):
				return "band member #%s is not among the declared attackers" % str(id)
		var band_why := CombatState.band_illegality(self, band)
		if band_why != "":
			return band_why
	# "Attacks each combat if able" (Juggernaut): every able must-attacker
	# has to be in the declaration (CR 508.1d attack requirements).
	for inst in players[pid].battlefield:
		if attacks_banned:
			break   # CR 508.1d — a restriction beats the requirement
		if inst.has_keyword(Mtg.Keyword.MUST_ATTACK) and not declared.has(inst) \
				and CombatState.attack_illegality(self, inst, defender) == "":
			return "%s attacks each combat if able" % inst.data.card_name
	if max_attackers > 0 and declared.size() > max_attackers:
		return "no more than %d creatures can attack each combat" % max_attackers
	# ATTACK COSTS (CR 508.1g — "as attackers are declared"): every cost of
	# every declared attacker is checked FIRST, so a declaration that has to
	# be refused leaves nothing spent (CONTRIBUTING.md rule 3), and only then paid.
	for inst in declared:
		for cost in inst.cur_attack_costs:
			if not cost["can_pay"].call(self, pid):
				return "%s can't attack unless %s" % [
					inst.data.card_name, String(cost["desc"])]
	for inst in declared:
		for cost in inst.cur_attack_costs:
			cost["pay"].call(self, pid)
	# THE CENSUS (Season of the Witch's "creatures that couldn't attack"):
	# taken NOW, whether or not anything attacks, because the declaration
	# is the only moment a creature can attack (CR 508.1a). A creature
	# tapped now and untapped later still couldn't attack; one that gets
	# defender after combat still could have.
	for inst in players[pid].battlefield:
		if not inst.is_creature():
			continue
		var able := not no_attacks_this_turn \
			and CombatState.attack_illegality(self, inst, defender) == ""
		if able:
			for cost in inst.cur_attack_costs:
				if not cost["can_pay"].call(self, pid):
					able = false
					break
		if undo_log != null: _rec(inst, &"could_attack_this_turn")
		inst.could_attack_this_turn = able
	if undo_log != null:
		_rec(combat, &"bands")
		_rec(combat, &"attackers")
		_rec(self, &"awaiting_attackers")
		_rec(self, &"priority_player")
		_rec(self, &"_passes")
	combat.bands = band_list.duplicate(true)
	var newly_tapped: Array[CardInstance] = []
	for inst in declared:
		combat.attackers[inst.id] = true
		if undo_log != null: _rec(inst, &"attacked_this_turn")
		inst.attacked_this_turn = true
		if not inst.has_keyword(Mtg.Keyword.VIGILANCE) and not inst.tapped \
				and not attacks_without_tapping.has(pid):
			if undo_log != null: _rec(inst, &"tapped")
			inst.tapped = true   # attacking taps (CR 508.1f)
			newly_tapped.append(inst)
	# Tap state feeds conditional statics (Castle's "untapped creatures...").
	recalculate()
	# Attacking is "becoming tapped" too (an animated land with Psychic
	# Venom attached stings its controller for attacking).
	for inst in newly_tapped:
		dispatch_event(Mtg.EventType.BECAME_TAPPED,
			{"instance": inst, "controller": inst.controller_id})
	awaiting_attackers = false
	if declared.is_empty():
		log_line("%s declares no attackers" % players[pid].player_name)
	else:
		var names := PackedStringArray()
		for inst in declared:
			names.append(inst.data.card_name)
		log_line("%s attacks with: %s" % [players[pid].player_name, ", ".join(names)])
		if undo_log != null: _rec(players[pid], &"attacked_this_turn")
		players[pid].attacked_this_turn = true
		dispatch_event(Mtg.EventType.DECLARED_ATTACKERS, {"attackers": declared})
	_open_priority()
	return ""


## Declare blockers (defending player, during the declare-blockers step).
## [param block_map] maps blocker instance id -> attacker instance id.
## Any number of blockers may gang up on one attacker (multi-block);
## blocking a band member commits the blocker against the whole band.
## ONE BLOCK MAP SHAPE, whatever the caller wrote. `{blocker: attacker}`
## and `{blocker: [attacker, attacker]}` are both accepted — the first is
## what every caller wrote before one-to-many blocks existed and what the
## UI, the AI and Camouflage still write — and both come out as
## `{blocker: Array[int]}`. Duplicates and empty lists are dropped, so a
## caller cannot declare the same block twice or name a blocker with
## nothing to block.
func _normalise_block_map(block_map: Dictionary) -> Dictionary:
	var out := {}
	for blocker_id in block_map:
		var value: Variant = block_map[blocker_id]
		var against: Array = []
		if value is Array:
			for id in value:
				if not against.has(int(id)):
					against.append(int(id))
		else:
			against.append(int(value))
		if not against.is_empty():
			out[int(blocker_id)] = against
	return out


## HOW MANY ATTACKERS [param blocker] MAY BLOCK right now (CR 509.1b): 1
## for almost every creature, more where an effect says so, and -1 for any
## number. The printed permission
## ([member CardInstance.cur_extra_blocks], Two-Headed Giant of Foriys) and
## the granted one ([member CardInstance.extra_blocks_this_turn], Blaze of
## Glory) are taken together, with "any number" winning over any count —
## two permissions never add up to fewer blocks than one.
##
## PUBLIC because the duel screen needs the same answer to know when to
## stop offering a second block; a UI that computed it separately would be
## a second opinion about a rule.
func blocks_allowed(blocker: CardInstance) -> int:
	if blocker.cur_extra_blocks < 0 or blocker.extra_blocks_this_turn < 0:
		return -1
	return 1 + maxi(blocker.cur_extra_blocks, blocker.extra_blocks_this_turn)


func declare_blockers(pid: int, block_map: Dictionary) -> String:
	if game_over:
		return "the game is over"
	if not awaiting_blockers:
		return "not the time to declare blockers"
	if pid != opponent_of(active_player):
		return "only the defending player declares blockers"
	# CAMOUFLAGE: "instead of declaring blockers, each defending player
	# chooses any number of creatures they control and divides them into
	# a number of piles equal to the number of attacking creatures …
	# Assign each pile to a different one of those attacking creatures at
	# random." The defender's declaration is discarded; the piles are the
	# defender's CHOICE, one turn-based question per creature (the hold
	# below — a human seat answers them pile by pile), and the deal is
	# game.rng's, so a seeded duel replays it.
	_begin_cost_choices()
	if camouflage_this_turn:
		block_map = _camouflage_block_map(pid)
		if awaiting_choice != null:
			return ""   # held on a pile question; nothing was changed
	# ONE-TO-MANY BLOCKS (CR 509.1b). A value may be a single attacker id —
	# what every caller wrote before 2026-09-02 and still writes — or an
	# ARRAY of them, for a creature an effect lets block more than one
	# (Two-Headed Giant of Foriys, Blaze of Glory). Normalised once here so
	# nothing below has to know which form it was given.
	var declared_blocks := _normalise_block_map(block_map)
	for blocker_id in declared_blocks:
		var blocker := find_instance(int(blocker_id))
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD \
				or blocker.controller_id != pid:
			return "blocker #%s is not a creature you control" % str(blocker_id)
		var against: Array = declared_blocks[blocker_id]
		# A creature blocks ONE attacker unless something says otherwise
		# (CR 509.1b). -1 on either field means any number.
		var allowance := blocks_allowed(blocker)
		if allowance >= 0 and against.size() > allowance:
			return "%s can block only %d attacker(s)" % [
				blocker.data.card_name, allowance]
		for attacker_id in against:
			var attacker := find_instance(int(attacker_id))
			if attacker == null or not combat.attackers.has(attacker.id):
				return "#%s is not an attacking creature" % str(attacker_id)
			var why := CombatState.block_illegality(self, blocker, attacker, pid)
			if why != "":
				return "%s can't block %s: %s" % [
					blocker.data.card_name, attacker.data.card_name, why]
	# THE CAP IS ON BLOCKING CREATURES, not on blocks (Caverns of Despair:
	# "no more than one creature can block each combat"), so a creature
	# that blocks two attackers still counts once.
	if max_blockers > 0 and declared_blocks.size() > max_blockers:
		return "no more than %d creatures can block each combat" % max_blockers
	# "All creatures able to block it do so" (Lure): every untapped
	# creature the defender controls that COULD legally block a lured
	# attacker must be declared against one of them (CR 509.1c).
	# (Under Camouflage the blocks are the spell's procedure, not a
	# declaration, so the requirements below have nothing to check.)
	for attacker_id in combat.attackers:
		var lured := find_instance(attacker_id)
		if lured == null or not lured.cur_must_be_blocked or camouflage_this_turn:
			continue
		for candidate in players[pid].battlefield:
			if not candidate.is_creature() or candidate.tapped:
				continue
			# CR 509.1c: the requirement is "all creatures able to block IT
			# do so" — blocking some OTHER attacker does not satisfy it.
			if (declared_blocks.get(candidate.id, []) as Array).has(lured.id):
				continue
			# ... but a cap on blockers (Caverns of Despair) is a restriction
			# and beats the requirement (CR 509.1c/508.1d).
			if max_blockers > 0 and declared_blocks.size() >= max_blockers:
				continue
			if lured.cur_must_be_blocked_filter.is_valid() \
					and not lured.cur_must_be_blocked_filter.call(candidate):
				continue
			if CombatState.block_illegality(self, candidate, lured, pid) == "":
				return "%s must block %s if able" % [
					candidate.data.card_name, lured.data.card_name]
	# "It blocks EACH attacking creature this turn if able" (Blaze of
	# Glory): a creature under that order must be in the declaration —
	# against every attacker it could legally block, since the same card
	# also lifts the one-block limit. Before one-to-many blocks existed
	# this could only ask for one of them, which is the ledger row the
	# 2026-09-02 pass closed. A VALIDATION, so it sits with the others
	# above the first write: until the 2026-09-02 sweep it ran after the
	# block map had been filled, and a refused declaration left its
	# blocks behind (CONTRIBUTING.md rule 3 — a refusal changes nothing).
	for candidate in players[pid].battlefield:
		if not candidate.must_block_this_turn or candidate.tapped \
				or camouflage_this_turn:
			continue
		var declared: Array = declared_blocks.get(candidate.id, [])
		var allowed := blocks_allowed(candidate)
		for attacker_id in combat.attackers:
			if declared.has(int(attacker_id)):
				continue
			# It cannot be asked to block more than it may.
			if allowed >= 0 and declared.size() >= allowed:
				break
			var target := find_instance(attacker_id)
			if target != null \
					and CombatState.block_illegality(self, candidate, target, pid) == "":
				return "%s must block %s if able" % [
					candidate.data.card_name, target.data.card_name]
	# THE JOURNAL (see `undo_log`): nothing above this line has written
	# anything, and everything below does — the combat collections as a
	# whole (the way declare_attackers records them), the per-blocker
	# history, and the fields _open_priority rewrites. A search that
	# explored a block used to leave `combat.blocks` populated after its
	# unwind, with the declare-blockers window closed (2026-09-02).
	if undo_log != null:
		undo_log.record_object(combat)
		_rec(self, &"awaiting_blockers")
		_rec(self, &"priority_player")
		_rec(self, &"_passes")
		for blocker_id in declared_blocks:
			var blocker := find_instance(int(blocker_id))
			_rec(blocker, &"blocked_this_turn")
			_rec(blocker, &"blocked_ids_this_turn")
	for blocker_id in declared_blocks:
		var against: Array = declared_blocks[blocker_id]
		var blocker := find_instance(int(blocker_id))
		# The FIRST attacker goes in `blocks` and the rest in
		# `extra_blocks`, which is the shape CR 509.1b describes and the
		# shape two dozen cards' `blocks.has(id)` depends on.
		combat.blocks[int(blocker_id)] = int(against[0])
		if against.size() > 1:
			var also: Array = against.slice(1)
			combat.extra_blocks[int(blocker_id)] = also
		blocker.blocked_this_turn = true
		for attacker_id in against:
			# CR 509.1h: being blocked is a status the attacker keeps for
			# the rest of the combat, even if every blocker later dies or
			# leaves.
			combat.blocked_attackers[int(attacker_id)] = true
			var blocked := find_instance(int(attacker_id))
			# BLOCK HISTORY (the Glyph cycle): the blocker remembers WHO it
			# blocked this turn and who controlled them at that moment —
			# "the player who controlled that creature the last time it
			# became blocked by that Wall" is Glyph of Reincarnation,
			# verbatim.
			blocker.blocked_ids_this_turn[blocked.id] = blocked.controller_id
			log_line("%s blocks %s" % [
				blocker.data.card_name, blocked.data.card_name])
	awaiting_blockers = false
	# "Blocks or becomes blocked" triggers, one event per PAIR
	# (Cockatrice/Basilisk hear both directions from the same event) — so a
	# creature blocking two attackers fires two.
	for blocker_id in declared_blocks:
		for attacker_id in declared_blocks[blocker_id]:
			dispatch_event(Mtg.EventType.BLOCKED, {
				"attacker": find_instance(int(attacker_id)),
				"blocker": find_instance(int(blocker_id))})
	# RAMPAGE (CR 702.23): a blocked attacker with rampage N gets +N/+N
	# for each blocker beyond the first. Applied before the
	# blockers-declared event so triggers that read power see the pumped
	# value.
	for attacker_id in combat.attackers:
		var attacker := find_instance(attacker_id)
		if attacker == null or attacker.cur_rampage <= 0:
			continue
		var blocker_count := combat.blockers_of_band(combat.band_of(attacker_id)).size()
		if blocker_count <= 1:
			continue
		var bonus: int = attacker.cur_rampage * (blocker_count - 1)
		continuous.add_until_eot_pump(attacker_id, bonus, bonus)
		log_line("%s's rampage %d gives it +%d/+%d (%d blockers)" % [
			attacker.data.card_name, attacker.cur_rampage, bonus, bonus, blocker_count])
	recalculate()
	# THE DAMAGE ASSIGNMENT ORDER (CR 509.2): announced by the ATTACKING
	# player as blockers are declared, once per attacker with more than one
	# blocker. Under the 1997 ruleset there is no such order at all
	# (RulesOptions.free_damage_assignment) — but announcing it costs
	# nothing and the fork simply stops enforcing it.
	for band in combat.all_bands():
		var ganged := combat.blockers_of_band(band)
		if ganged.size() < 2 or band.is_empty():
			continue
		var lead := find_instance(int(band[0]))
		if lead == null:
			continue
		var wanted: Array = agents[active_player].order_blockers(self, lead, ganged)
		var ordered: Array = []
		for id in wanted:
			if ganged.has(int(id)) and not ordered.has(int(id)):
				ordered.append(int(id))
		for id in ganged:
			if not ordered.has(id):
				ordered.append(id)
		combat.damage_order[int(band[0])] = ordered
	# …then the all-blocks-final event ("attacks and isn't blocked").
	dispatch_event(Mtg.EventType.BLOCKERS_DECLARED, {})
	_open_priority()
	return ""


## CAMOUFLAGE's piles. "Each defending player chooses any number of
## creatures they control and divides them into a number of piles equal to
## the number of attacking creatures … Assign each pile to a different one
## of those attacking creatures at random. Each creature in a pile that can
## block the creature that pile is assigned to does so."
##
## The defender is asked ONE turn-based OPTION question per creature that
## could block at all — "No pile" or "Pile 1" … "Pile N" (N = the
## attackers) — through the cost hold, so a human seat answers them one by
## one and the declaration is re-issued with the answers parked (see
## [method _replay_cost_action], kind "blockers"). The hint is a random
## pile, which is what the engine used to roll on the defender's behalf;
## it is rolled only for a question that is actually being asked fresh
## (not held, not served from the mailbox), so a seeded duel's rng stream
## does not depend on how many times a human seat re-ran the declaration
## (CONTRIBUTING.md rule 7). Then the attackers are shuffled and pile i goes to
## the i-th of them; a pile member that can legally block its attacker
## blocks it, the rest stay home — Caverns of Despair's cap on blocking
## creatures still applies (CR 509.1b).
##
## A tapped creature, or one that could block none of the attackers, is
## not asked: it could be put in a pile but would block nothing, so the
## question would change nothing. Returns the block map; when a seat is
## holding the duel on a question, [member awaiting_choice] is set and the
## map is empty — the caller returns "" having changed nothing.
func _camouflage_block_map(pid: int) -> Dictionary:
	var out: Dictionary = {}
	var attacker_ids: Array = combat.attackers.keys()
	if attacker_ids.is_empty():
		return out
	var labels: Array[String] = ["No pile"]
	for i in attacker_ids.size():
		labels.append("Pile %d" % (i + 1))
	var piles: Dictionary = {}   # blocker id → pile number (1-based)
	for inst in players[pid].battlefield:
		if not inst.is_creature() or inst.tapped:
			continue
		var can_block_something := false
		for attacker_id in attacker_ids:
			var attacker := find_instance(attacker_id)
			if attacker != null \
					and CombatState.block_illegality(self, inst, attacker, pid) == "":
				can_block_something = true
				break
		if not can_block_something:
			continue
		var q := _turn_question(pid, "Camouflage", PlayerChoice.Kind.OPTION,
			"Camouflage: which pile for %s?" % inst.data.card_name)
		q.options = labels
		if _hold_cost_choice(q, {"kind": "blockers", "pid": pid}):
			return {}
		var hint := 0
		if _cost_asked > _cost_answers:   # asked fresh, not served parked
			hint = 1 + rng.randi_range(0, attacker_ids.size() - 1)
		q.hint = hint
		var pile := _ask_turn_option(pid, "Camouflage", labels, q.prompt, hint)
		if pile > 0:
			piles[inst.id] = pile
	# The deal: shuffle the attackers, pile i → the i-th of them.
	for i in range(attacker_ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = attacker_ids[i]
		attacker_ids[i] = attacker_ids[j]
		attacker_ids[j] = swap
	for blocker_id in piles:
		if max_blockers > 0 and out.size() >= max_blockers:
			break   # Caverns of Despair caps the piles' blocks too (CR 509.1b)
		var blocker := find_instance(int(blocker_id))
		var attacker := find_instance(int(attacker_ids[int(piles[blocker_id]) - 1]))
		if blocker == null or attacker == null:
			continue
		if CombatState.block_illegality(self, blocker, attacker, pid) != "":
			log_line("%s's pile went to %s, which it can't block" % [
				blocker.data.card_name, attacker.data.card_name])
			continue
		out[blocker.id] = attacker.id
	log_line("Camouflage deals the piles to the attackers at random")
	return out


# -------------------------------------------------------- mutation helpers --
# The ONLY functions that change life totals, zones, or damage. Effects,
# triggers and combat all funnel through here.

## Deal damage from [param source] to a target (player or creature).
## Protection from the source's color prevents damage to a creature —
## the D of DEBT (CR 702.16e). Returns the amount ACTUALLY dealt after
## prevention (Drain Life's "damage dealt this way" reads it).
## [param is_combat] marks COMBAT damage (set by the combat-damage waves);
## effects that prevent only combat damage — Gaseous Form's "dealt to and
## dealt by enchanted creature" — read it, so a creature under Gaseous
## Form can still be Bolted and can still use a ping ability.
##
## TWO HALVES since docs/duel-todo.md §6.8: [method _plan_damage] builds
## the [DamagePacket] — damage as an OBJECT, which is what the 1997 game
## let a prevention effect target — and [method _land_damage] runs it
## through the victim's prevention gates and applies what survives. With
## no damage-prevention window open the two run back to back and this is
## the same function it always was. The window goes between them.
func deal_damage(source: CardInstance, target: TargetRef, amount: int,
		is_combat := false, after := Callable()) -> int:
	var packet := _plan_damage(source, target, amount, is_combat)
	if packet == null:
		if after.is_valid():
			after.call(0)
		return 0
	if after.is_valid():
		packet.after_landing.append(after)
	if _queue_damage(packet):
		# The window has it now; it lands when the step ends. The return
		# value is what is PLANNED, which is all anyone can know yet —
		# a caller that needs the real answer passes [param after].
		return packet.remaining()
	return _land_damage(packet)


## The PLANNING half: everything that decides whether a damage EVENT
## exists at all. Returns the [DamagePacket], or null when the source's
## own "prevent all damage it would deal" replacement means no damage is
## ever dealt — a replacement on the SOURCE applies before the event, so
## there is never a packet for a prevention window to point at (CR 615.8
## orders replacements before prevention; `Duel.hlp`'s window only ever
## sees damage that is actually about to be dealt).
##
## [param from_redirect] marks a packet produced by redirection rather
## than by an original event — see [member DamagePacket.from_redirect].
func _plan_damage(source: CardInstance, target: TargetRef, amount: int,
		is_combat: bool, from_redirect := false) -> DamagePacket:
	if amount <= 0 or target == null:
		return null
	if source.face_down:
		turn_face_up(source)   # dealing damage turns it up too
	if source.cur_prevent_all_damage_dealt:
		log_line("%s's damage is prevented" % source.data.card_name)
		return null
	if is_combat and source.cur_prevent_combat_damage_dealt:
		log_line("%s's combat damage is prevented" % source.data.card_name)
		return null
	var packet := DamagePacket.new()
	_rec(self, &"_next_packet_id")
	packet.id = _next_packet_id
	_next_packet_id += 1
	packet.source = source
	packet.target = target
	packet.amount = amount
	packet.is_combat = is_combat
	packet.from_redirect = from_redirect
	return packet


## The LANDING half: the victim's own prevention gates, in the order
## docs/mechanics.md §6 lists them, and then the damage itself. Returns
## the amount ACTUALLY dealt.
##
## A gate that eats the WHOLE event (a Circle of Protection shield,
## protection, an immunity) marks the packet fully prevented rather than
## just returning, so a caller holding the packet can still read what
## happened to it.
func _land_damage(packet: DamagePacket) -> int:
	var dealt := _land_damage_impl(packet)
	# EVERY path fires the callbacks, 0 included: "you gain life equal to
	# the damage dealt this way" gains nothing when the damage was
	# prevented, and the card's own `if dealt > 0` is what says so.
	for cb in packet.after_landing:
		cb.call(dealt)
	return dealt


func _land_damage_impl(packet: DamagePacket) -> int:
	var source: CardInstance = packet.source
	var target: TargetRef = packet.target
	var is_combat: bool = packet.is_combat
	var amount := packet.remaining()
	if source == null or target == null or amount <= 0:
		return 0
	# "ALL damage that would be dealt this turn by <this source> is dealt to
	# <someone> instead" (Reverberation) — a replacement on the SOURCE, so
	# it is asked before anything about the victim. A packet that is itself
	# the product of a redirect is left alone, or the two would loop.
	if source.damage_all_redirect_to >= 0 and not packet.from_redirect:
		log_line("%s's damage is turned on %s" % [
			source.data.card_name,
			players[source.damage_all_redirect_to].player_name])
		return _redirect_damage(packet,
			TargetRef.player(source.damage_all_redirect_to))
	if target.is_player:
		var p := players[target.player_id]
		# ONE-SHOT REPLACEMENTS aimed at this seat (Forcefield, Dark Sphere,
		# Eye for an Eye, Nova Pentacle, Shimian Night Stalker). A
		# replacement happens before any prevention (CR 614/616), so this is
		# the first gate of all.
		for i in range(p.damage_replacements.size() - 1, -1, -1):
			var rep: Dictionary = p.damage_replacements[i]
			if not rep["filter"].call(self, packet):
				continue
			if not bool(rep.get("all_turn", false)):
				p.damage_replacements.remove_at(i)
			log_line("%s replaces %s's damage" % [
				String(rep["desc"]), source.data.card_name])
			var verdict: int = rep["apply"].call(self, packet)
			if verdict >= 0:
				return verdict
			amount = packet.remaining()
			if amount <= 0:
				return 0
		# "All damage that would be dealt to you by artifacts is dealt to
		# this creature instead" (Martyrs of Korlis) — a redirection, so
		# it happens before any of the player's own prevention.
		# DAMAGE CAPS (Forethought Amulet): a REPLACEMENT, so it happens
		# before any prevention and the packet is not "prevented" — it was
		# only ever this big (CR 614.1).
		for cap in p.damage_caps:
			if amount < int(cap["threshold"]):
				continue
			if not cap["filter"].call(self, source):
				continue
			var capped: int = int(cap["becomes"])
			if capped >= amount:
				continue
			log_line("%s's damage to %s is reduced to %d (%s)" % [
				source.data.card_name, p.player_name, capped, String(cap["desc"])])
			packet.amount = capped
			amount = packet.remaining()
			if amount <= 0:
				return 0
		# "The next time a source of your choice would deal damage to you
		# this turn, prevent that damage. You gain life equal to the damage
		# prevented" (Reverse Damage) — one shot, and only from the source
		# it named.
		var reverse_at := p.reverse_damage_sources.find(source.id)
		if reverse_at >= 0:
			p.reverse_damage_sources.remove_at(reverse_at)
			packet.prevent(amount)
			log_line("%s turns %d damage from %s into life" % [
				p.player_name, amount, source.data.card_name])
			adjust_life(target.player_id, amount)
			return 0
		# "All damage unblocked creatures would deal to you is dealt to this
		# creature instead" (Veteran Bodyguard).
		# "All damage UNBLOCKED creatures would deal to you" — the blocked
		# STATUS, not "does it have a blocker right now": a trampler whose
		# blocker regenerated is still blocked and its spill-over is not
		# redirected (CR 509.1h).
		if is_combat and p.combat_damage_redirect != -1 and source.is_creature() \
				and combat.attackers.has(source.id) \
				and not combat.was_blocked(combat.band_of(source.id)):
			var guard := find_instance(p.combat_damage_redirect)
			if guard != null and guard.zone == Mtg.Zone.BATTLEFIELD and guard != source:
				log_line("%s takes the blow for %s" % [guard.data.card_name, p.player_name])
				return _redirect_damage(packet, TargetRef.card(guard))
		# LIVE types (CR 611.2, 613): a creature something has turned into
		# an artifact counts, a card printed as one but not now does not.
		if p.artifact_damage_redirect != -1 and source.is_type(Mtg.CardType.ARTIFACT):
			var shield := find_instance(p.artifact_damage_redirect)
			if shield != null and shield.zone == Mtg.Zone.BATTLEFIELD:
				log_line("%s's damage is redirected to %s" % [
					source.data.card_name, shield.data.card_name])
				return _redirect_damage(packet, TargetRef.card(shield))
		# Circle of Protection shields: one-shot, color-matched (the shield
		# eats the WHOLE damage event, like the original CoP wording).
		for i in p.prevention_shields.size():
			if (p.prevention_shields[i] & source.cur_colors) != 0:
				p.prevention_shields.remove_at(i)
				packet.prevent(amount)
				log_line("%s's damage to %s is prevented (circle of protection)" % [
					source.data.card_name, p.player_name])
				return 0
		# Predicate shields (Circle of Protection: Artifacts, Scarecrow).
		for i in p.prevention_shield_filters.size():
			if p.prevention_shield_filters[i]["filter"].call(source):
				# An "all_turn" shield is not consumed: Scarecrow buys the
				# whole turn against one KIND of source, not one packet.
				if not bool(p.prevention_shield_filters[i].get("all_turn", false)):
					p.prevention_shield_filters.remove_at(i)
				packet.prevent(amount)
				log_line("%s's damage to %s is prevented (circle of protection)" % [
					source.data.card_name, p.player_name])
				return 0
		# Amount-based prevention (Healing Salve): eats damage point for point.
		# SIMPLIFIED (docs/ROADMAP.md), and only under the 1997 window:
		# `Duel.hlp` lets the player SPREAD a pool across packets by hand
		# ("you may prevent the damage from three ..."); ours is spent
		# greedily on the packets in the order they land. Identical with
		# one packet, which is every case outside a prevention step.
		if p.damage_prevention > 0:
			var soaked := packet.prevent(mini(p.damage_prevention, amount))
			_rec(p, &"damage_prevention")
			p.damage_prevention -= soaked
			amount = packet.remaining()
			log_line("%d damage to %s is prevented" % [soaked, p.player_name])
			if amount <= 0:
				return 0
		# Ali from Cairo: damage can't take you below the floor.
		if p.min_life_from_damage > 0 and p.life - amount < p.min_life_from_damage:
			packet.prevent(amount - maxi(p.life - p.min_life_from_damage, 0))
			amount = packet.remaining()
			if amount <= 0:
				log_line("%s's damage to %s is reduced to nothing (life floor)" % [
					source.data.card_name, p.player_name])
				return 0
		if undo_log != null:
			_rec(p, &"artifact_damage_this_turn")
			_rec(p, &"damage_taken_this_turn")
			_rec(p, &"life")
			_rec(self, &"damage_dealt_this_turn")
			_rec(source, &"damaged_players_this_turn")
		if source.is_type(Mtg.CardType.ARTIFACT):   # live types, as above
			p.artifact_damage_this_turn += amount
		p.damage_taken_this_turn += amount
		damage_dealt_this_turn[source.id] = \
			int(damage_dealt_this_turn.get(source.id, 0)) + amount
		p.life -= amount
		if not source.damaged_players_this_turn.has(target.player_id):
			source.damaged_players_this_turn.append(target.player_id)
		log_line("%s deals %d damage to %s (life %d)" % [
			source.data.card_name, amount, p.player_name, p.life])
		dispatch_event(Mtg.EventType.DAMAGE_DEALT,
			{"source": source, "amount": amount, "to_player": target.player_id,
			"packet": packet})
	else:
		var inst := find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return 0
		# "Until end of turn, if damage would be dealt to any creature, you
		# may have that damage dealt to you instead" (Blood of the Martyr).
		# A replacement, so it is asked before every prevention gate, and
		# "may" means the offer is really made — once per packet.
		if not packet.from_redirect:
			for taker in players:
				if not taker.may_take_creature_damage:
					continue
				if not agents[taker.id].choose_yes_no(self, taker.id,
						"Take %d damage from %s in %s's place?" % [
							amount, source.data.card_name, inst.data.card_name],
						true):
					continue
				return _redirect_damage(packet, TargetRef.player(taker.id))
		# "For each 1 damage that would be dealt to this creature, if it has
		# a +1/+1 counter on it, remove a counter and prevent that 1 damage"
		# (Rock Hydra) — a replacement that eats counters point for point.
		if inst.damage_eats_counters != "":
			var kind := inst.damage_eats_counters
			var have: int = int(inst.counters.get(kind, 0))
			var eaten: int = mini(have, amount)
			if eaten > 0:
				_rec(inst, &"counters")
				if have - eaten <= 0:
					inst.counters.erase(kind)
				else:
					inst.counters[kind] = have - eaten
				packet.prevent(eaten)
				amount = packet.remaining()
				log_line("%s sheds %d %s counter(s) and prevents %d damage" % [
					inst.data.card_name, eaten, kind, eaten])
				recalculate()
				if amount <= 0:
					check_state_based_actions()
					return 0
		# A face-down creature that would be dealt damage is turned face up
		# first (Illusionary Mask) — the damage then hits its real body.
		if inst.face_down:
			turn_face_up(inst)
		# "Damage that would be dealt to that creature this turn can't be
		# prevented or dealt instead to another permanent or player"
		# (Whippoorwill). Every gate below is a prevention or a
		# redirection — protection included, since CR 702.16e makes
		# protection prevent the damage — so the whole block is skipped and
		# the damage is marked exactly as dealt.
		if not inst.damage_unpreventable_this_turn:
			if (inst.cur_protection & source.cur_colors) != 0:
				packet.prevent(amount)
				log_line("%s's damage to %s is prevented (protection)" % [
					source.data.card_name, inst.data.card_name])
				return 0
			# "Prevent all damage dealt to this creature by creatures" (Uncle
			# Istvan) — covers combat AND creature-sourced ability damage.
			if inst.cur_prevent_damage_from_creatures and source.is_creature():
				packet.prevent(amount)
				log_line("%s's damage to %s is prevented (creature damage)" % [
					source.data.card_name, inst.data.card_name])
				return 0
			# "That damage is dealt to you instead" (Jade Monolith) — one
			# shot, and from the source the Monolith named when it has one
			# (Personal Incarnation names none: any source).
			if inst.damage_redirects > 0 and inst.damage_redirect_to >= 0 \
					and (inst.damage_redirect_sources.is_empty()
						or inst.damage_redirect_sources.has(source.id)):
				if undo_log != null:
					_rec(inst, &"damage_redirects")
					_rec(inst, &"damage_redirect_to")
					_rec(inst, &"damage_redirect_sources")
				inst.damage_redirects -= 1
				var named_at := inst.damage_redirect_sources.find(source.id)
				if named_at >= 0:
					inst.damage_redirect_sources.remove_at(named_at)
				var soak := inst.damage_redirect_to
				if inst.damage_redirects <= 0:
					inst.damage_redirect_to = -1
					inst.damage_redirect_sources.clear()
				log_line("%s's damage is redirected to %s" % [
					inst.data.card_name, players[soak].player_name])
				return _redirect_damage(packet, TargetRef.player(soak))
			# "The next 1 damage that would be dealt to this creature this
			# turn is dealt to its owner instead" (Personal Incarnation) —
			# METERED: each activation moves ONE point and the rest of the
			# event lands here. `Duel.hlp`: *"owner may redirect any amount
			# of damage from it to himself or herself."*
			if inst.damage_point_redirects > 0 and inst.damage_point_redirect_to >= 0:
				var landed_elsewhere := _divert_damage_points(packet, inst)
				amount = packet.remaining()
				if amount <= 0:
					return landed_elsewhere
				# The rest falls through the remaining gates and lands; the
				# diverted part is added back to the answer at the end.
				return landed_elsewhere + _land_damage_rest(packet, inst, amount, is_combat)
		return _land_damage_rest(packet, inst, amount, is_combat)
	check_state_based_actions()
	return amount


## The tail of [method _land_damage_impl]'s creature branch: the remaining
## prevention gates (inside `if not inst.damage_unpreventable_this_turn`)
## and then the marking of the damage itself. Its own function so that a
## METERED redirect (Personal Incarnation) can hand the rest of the event
## down the same gates after it has taken its points. [param amount] is
## `packet.remaining()` on entry. Returns what was marked on [param inst].
func _land_damage_rest(packet: DamagePacket, inst: CardInstance, amount: int,
		is_combat: bool) -> int:
	var source: CardInstance = packet.source
	if not inst.damage_unpreventable_this_turn:
		if inst.cur_prevent_all_damage_taken:
			packet.prevent(amount)
			log_line("all damage to %s is prevented" % inst.data.card_name)
			return 0
		if is_combat and inst.cur_prevent_combat_damage_taken:
			packet.prevent(amount)
			log_line("combat damage to %s is prevented" % inst.data.card_name)
			return 0
		# Source-filtered immunities ("...by creatures it's blocking",
		# "...by artifact sources", "...by Deserts"); an entry marked
		# combat-only (Enchanted Being, Marble Priest) lets a pinger
		# through.
		for immunity in inst.cur_damage_immunity:
			if bool(immunity.get("combat", false)) and not is_combat:
				continue
			if immunity["filter"].call(self, source):
				packet.prevent(amount)
				log_line("damage to %s from %s is prevented (%s)" % [
					inst.data.card_name, source.data.card_name, immunity["desc"]])
				return 0
		# Amount-based prevention (Healing Salve, Samite Healer).
		if inst.prevention > 0:
			var soaked := packet.prevent(mini(inst.prevention, amount))
			_rec(inst, &"prevention")
			inst.prevention -= soaked
			amount = packet.remaining()
			log_line("%d damage to %s is prevented" % [soaked, inst.data.card_name])
			if amount <= 0:
				return 0
	if undo_log != null:
		_rec(inst, &"damage")
		_rec(inst, &"damaged_by_this_turn")
		_rec(inst, &"damage_from_this_turn")
		_rec(self, &"damage_dealt_this_turn")
	inst.damage += amount
	damage_dealt_this_turn[source.id] = \
		int(damage_dealt_this_turn.get(source.id, 0)) + amount
	if not inst.damaged_by_this_turn.has(source.id):
		inst.damaged_by_this_turn.append(source.id)
	inst.damage_from_this_turn[source.id] = \
		int(inst.damage_from_this_turn.get(source.id, 0)) + amount
	log_line("%s deals %d damage to %s (%d marked)" % [
		source.data.card_name, amount, inst.data.card_name, inst.damage])
	# "Whenever this creature deals damage to a creature this turn, ..."
	# (Runesword) — fired while the victim is still on the battlefield.
	for watcher in damage_watchers.duplicate():
		if int(watcher["source_id"]) == source.id:
			watcher["callback"].call(self, source, inst, amount)
	# "Whenever that creature is dealt damage this turn, you gain that
	# much life" (Glyph of Life) — a floating watch, not a permanent's
	# trigger, so it survives the Glyph itself being long gone.
	for watch in life_on_damage_watchers:
		if int(watch["instance_id"]) != inst.id:
			continue
		if bool(watch["attackers_only"]) and not combat.attackers.has(source.id):
			continue
		adjust_life(int(watch["controller"]), amount)
	dispatch_event(Mtg.EventType.DAMAGE_DEALT,
		{"source": source, "amount": amount, "to_instance": inst,
		"packet": packet})
	check_state_based_actions()
	return amount


## Public face of [method _redirect_damage], for the cards whose printed
## replacement redirects damage themselves (Nova Pentacle, Shimian Night
## Stalker, Reverberation). Returns what the redirected packet dealt.
func redirect_damage(packet: DamagePacket, to: TargetRef) -> int:
	return _redirect_damage(packet, to)


## "The next 1 damage that would be dealt to this creature this turn is
## dealt to its owner instead" (Personal Incarnation): book [param n]
## points of metered redirection on [param inst] toward seat [param to].
## Each point moves ONE point of one later damage event; the rest of that
## event lands on the creature. Cleared at cleanup and when the card
## leaves the battlefield.
func add_point_redirect(inst: CardInstance, to: int, n := 1) -> void:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or n <= 0 \
			or to < 0 or to >= players.size():
		return
	if undo_log != null:
		_rec(inst, &"damage_point_redirect_to")
		_rec(inst, &"damage_point_redirects")
	inst.damage_point_redirect_to = to
	inst.damage_point_redirects += n
	log_line("the next %d damage to %s will be dealt to %s instead" % [
		inst.damage_point_redirects, inst.data.card_name, players[to].player_name])


## The metered half of redirection: take as many of [param inst]'s
## booked points as [param packet] has left, split that many off into a
## NEW packet aimed at the booked seat, and either land it now or — with
## the 1997 window armed — queue it for `Duel.hlp`'s "second
## damage-prevention step". Returns what the split-off packet dealt (0
## when it is still waiting). The original packet keeps its
## [member DamagePacket.after_landing] callbacks and its caller's answer
## includes what landed here; a QUEUED split carries a copy of them so
## "you gain life equal to the damage dealt this way" still counts the
## moved point when that step ends — the two parts add up, never double.
func _divert_damage_points(packet: DamagePacket, inst: CardInstance) -> int:
	var to := inst.damage_point_redirect_to
	var moved := packet.divert(inst.damage_point_redirects)
	if moved <= 0:
		return 0
	if undo_log != null:
		_rec(inst, &"damage_point_redirects")
		_rec(inst, &"damage_point_redirect_to")
	inst.damage_point_redirects -= moved
	if inst.damage_point_redirects <= 0:
		inst.damage_point_redirect_to = -1
	log_line("%d of %s's damage to %s is dealt to %s instead" % [
		moved, packet.source.data.card_name, inst.data.card_name,
		players[to].player_name])
	var split := _plan_damage(packet.source, TargetRef.player(to), moved,
		packet.is_combat, true)
	if split == null:
		return 0
	if _damage_window_armed():
		split.after_landing = packet.after_landing.duplicate()
		if _queue_damage(split):
			return 0
	return _land_damage(split)


## REDIRECTION (Veteran Bodyguard, Martyrs of Korlis, Jade Monolith): the
## damage does not land here, it lands somewhere else, as a NEW packet with
## the same source and amount. CR 614 makes redirection a replacement, so
## the original packet never becomes damage at all — which is why this
## returns what the new packet dealt and not what the old one was worth.
func _redirect_damage(packet: DamagePacket, to: TargetRef) -> int:
	var moved := _plan_damage(packet.source, to, packet.remaining(),
		packet.is_combat, true)
	if moved == null:
		return 0
	# The waiting caller follows the damage: it is the same damage.
	moved.after_landing = packet.after_landing
	packet.after_landing = []
	if _queue_damage(moved):
		# `Duel.hlp`, Veteran Bodyguard: *"if a Bodyguard does redirect
		# damage, this causes a SECOND damage-prevention step that follows
		# the current one."* The redirected packet lands in THAT one.
		return 0
	return _land_damage(moved)


# ------------------------------------ THE DAMAGE-PREVENTION WINDOW (§6.8) --
#
# `Duel.hlp`, topic **Damage Dealing**: *"Once damage dealing has begun, no
# player can use fast effects until combat has ended. However, any damage
# dealing step during which damage is dealt is followed by a damage
# prevention step, during which both players can use effects that prevent
# and redirect damage. also, creatures killed or destroyed during combat
# can be regenerated."* And topic **Combat**: *"During damage dealing,
# players may use only damage prevention fast effects — those that
# prevent, heal, or redirect damage. ... No other kind of fast effects or
# spells are permitted."*
#
# It is TWO windows, because topic **Regeneration** says regeneration is
# not a prevention effect: *"You can use regeneration ONLY at the time
# when a creature is about to go to the graveyard."* So: damage is
# planned into [member damage_pending] instead of landing; the prevention
# window opens; when it closes every packet lands AT ONCE (the Circle of
# Protection ruling: *"This effect is applied to damage at the end of the
# damage prevention step, before any effects triggered by the damage take
# place"*); a redirect makes a SECOND prevention window; and then the
# regeneration window opens over whatever still holds lethal damage,
# with state-based actions still deferred so nothing has died yet.
#
# THE WHOLE THING IS A FORK (`RulesOptions.damage_prevention_window`,
# default OFF). Modern Magic has no such step at all — prevention is a
# replacement effect applied automatically, which is what our eight
# prevention gates already are. It is ALSO opt-in per seat
# ([method DecisionAgent.wants_damage_prevention_window]), so an AI-only
# duel and every headless test never pause even with the fork on.

## True while the DAMAGE PREVENTION step is open. Its own hold-open flag,
## shaped like [member awaiting_damage_assignment] — but the opposite kind
## of gate: every other hold-open flag is a blanket DENY, and this one is a
## restricted ALLOW (see [method _damage_window_refusal]).
## `@PROMPT_CHECKFEPHASE[0]` (`UIStrings.txt:1026`) is the original's name
## for it: `Damage prevention`.
var awaiting_damage_prevention := false

## True while the REGENERATION step is open — the moment `Duel.hlp` says a
## creature is "about to go to the graveyard".
## `@PROMPT_CHECKFEPHASE[11]` (`UIStrings.txt:1037`): `Use Regeneration
## Effects`.
var awaiting_regeneration := false

## The creatures the open regeneration window is about: instance ids
## holding lethal damage that nothing has swept yet.
var regeneration_candidates: Array[int] = []


## The waiting packet with [param id], or null once it has landed (or if
## it was never in a window at all). The mirror of [method find_instance],
## and what makes "the damage you aimed at is gone" detectable — a Circle
## targeting a packet that has already landed simply fizzles.
func find_packet(id: int) -> DamagePacket:
	for packet in damage_pending:
		if packet.id == id:
			return packet
	return null


## "A source of your choice" (CR 609.7): every object a player may name
## as a source of damage right now — each permanent on either side and
## each spell on the stack (the objects on the stack refer to; the
## command zone does not exist here). [param accept] narrows it
## (`func(source: CardInstance) -> bool` — "a red source", "an artifact
## source"); a source need not be able to deal damage to be chosen.
## Ranked by [method rank_damage_sources] for [param threatened] when it
## is given, so the first entry is the one about to deal damage.
func damage_sources(accept: Callable = Callable(),
		threatened: TargetRef = null) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in all_battlefield():
		if not accept.is_valid() or bool(accept.call(inst)):
			out.append(inst)
	for item in stack:
		if item.card != null and item.card.zone == Mtg.Zone.STACK \
				and not out.has(item.card):
			if not accept.is_valid() or bool(accept.call(item.card)):
				out.append(item.card)
	if threatened != null:
		out = rank_damage_sources(out, threatened)
	return out


## [param sources] ordered by how likely each is to be the NEXT to deal
## damage to [param victim] — the hint of every "source of your choice"
## question (the Circles of Protection, Reverse Damage, Jade Monolith,
## Nova Pentacle): a spell or ability on the stack aimed at the victim
## (topmost first), then a creature it is fighting in the current combat
## (an unblocked attacker for a player, a blocker or blocked attacker for
## a creature; the biggest first), then the other side's creatures by
## power, then the other side's other permanents, then the chooser's own.
func rank_damage_sources(sources: Array[CardInstance],
		victim: TargetRef) -> Array[CardInstance]:
	var scored: Array = []
	for inst in sources:
		scored.append([_threat_score(inst, victim), inst])
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return (a[1] as CardInstance).id < (b[1] as CardInstance).id)
	var out: Array[CardInstance] = []
	for pair in scored:
		out.append(pair[1])
	return out


func _threat_score(inst: CardInstance, victim: TargetRef) -> int:
	var whose := victim.player_id if victim.is_player else -1
	var victim_inst: CardInstance = null
	if not victim.is_player:
		victim_inst = find_instance(victim.instance_id)
		if victim_inst != null:
			whose = victim_inst.controller_id
	# On the stack, aimed at the victim: a spell, or an ability of this
	# source. The top of the stack resolves first.
	for i in range(stack.size() - 1, -1, -1):
		var item := stack[i]
		if item.card != inst:
			continue
		for ref in item.targets:
			if ref.same_object(victim):
				return 10000 + i
	# In combat with the victim.
	if inst.is_creature() and combat != null:
		if victim.is_player:
			if combat.attackers.has(inst.id) and inst.controller_id != whose \
					and not combat.was_blocked(combat.band_of(inst.id)):
				return 5000 + inst.cur_power
		elif victim_inst != null:
			if combat.is_blocking(inst.id, victim_inst.id) \
					or combat.is_blocking(victim_inst.id, inst.id):
				return 5000 + inst.cur_power
	if inst.controller_id == whose:
		return 0
	if inst.is_creature():
		return 1000 + inst.cur_power
	return 100


## Is a damage-prevention window possible at all right now? Both gates
## must say yes: the RULES FORK, and at least one seat that asked to be
## given the window. The second gate is what keeps `tests/cards/` and the
## Deck Lab untouched — without it every one of the 78 damage call sites
## would become a suspension point.
func _damage_window_armed() -> bool:
	if not rules.damage_prevention_window or game_over:
		return false
	for agent in agents:
		if agent.wants_damage_prevention_window():
			return true
	return false


## Put [param packet] in the window's queue instead of landing it, merging
## it into an existing packet with the same source and victim. Returns
## false when no window is armed, which is when [method deal_damage] lands
## the damage on the spot exactly as it always did.
##
## The merge is the Manabarbs ruling: *"damage ... during a damage
## prevention step is added to an existing Manabarbs damage packet (if
## there is one), so a single use of the CoP would target and prevent all
## of that damage."*
func _queue_damage(packet: DamagePacket) -> bool:
	if not _damage_window_armed():
		return false
	for existing in damage_pending:
		# A packet somebody is WAITING on ("you gain life equal to the
		# damage dealt this way") never merges: the answer has to stay its
		# own answer.
		if existing.matches(packet) and existing.after_landing.is_empty() \
				and packet.after_landing.is_empty():
			existing.absorb(packet)
			return true
	damage_pending.append(packet)
	return true


## Open the prevention window if there is damage waiting and anyone could
## do something about it. Called from [method _open_priority], which is
## every moment a player would receive priority — the same moment CR 704.3
## checks state-based actions, and the moment `Duel.hlp` puts the step.
##
## AUTO-SKIP when no seat holds a prevention effect at all. That is not a
## rules shortcut: the window's ONLY legal action is a prevention effect,
## so a window nobody could act in can only be passed.
func _maybe_open_damage_window() -> bool:
	if awaiting_damage_prevention or awaiting_regeneration:
		return false
	if damage_pending.is_empty() or not _damage_window_armed():
		return false
	var anyone := false
	for p in players:
		if _has_window_effect(p.id, true):
			anyone = true
			break
	if not anyone:
		_land_pending_damage()
		return awaiting_regeneration
	awaiting_damage_prevention = true
	log_line("Damage prevention")   # @PROMPT_CHECKFEPHASE[0]
	return true


## The original's own verb for leaving the window: `@PROMPT_ENDHEALING` =
## `end damage prevention` (`promptsX1.txt:1`). Identical to passing
## priority inside the window — it is the same round — and named
## separately because the 1997 button was.
func end_damage_prevention(pid: int) -> String:
	if not awaiting_damage_prevention and not awaiting_regeneration:
		return "no damage prevention step is open"
	return pass_priority(pid)


## What the open window is waiting for, for the UI:
## `{kind, prompt, packets, creatures}`. `kind` is `"prevention"` or
## `"regeneration"`; `prompt` is the original's own word for the step.
## Empty when no window is open.
func damage_prevention_request() -> Dictionary:
	if awaiting_damage_prevention:
		return {
			"kind": "prevention",
			"prompt": "Damage prevention",       # @PROMPT_CHECKFEPHASE[0]
			"packets": damage_pending.duplicate(),
			"creatures": [],
		}
	if awaiting_regeneration:
		var doomed: Array[CardInstance] = []
		for id in regeneration_candidates:
			var inst := find_instance(id)
			if inst != null:
				doomed.append(inst)
		return {
			"kind": "regeneration",
			"prompt": "Use Regeneration Effects",  # @PROMPT_CHECKFEPHASE[11]
			"packets": [],
			"creatures": doomed,
		}
	return {}


## Close whichever window is open. The prevention window lands its damage;
## the regeneration window releases the deferred state-based actions, which
## is when the creatures nobody saved finally die.
func _close_damage_window() -> void:
	if awaiting_regeneration:
		awaiting_regeneration = false
		regeneration_candidates.clear()
		end_simultaneous()   # the bracket _land_pending_damage left open
		_open_priority()
		return
	awaiting_damage_prevention = false
	_land_pending_damage()


## Every waiting packet lands AT ONCE. The Circle of Protection ruling is
## explicit that this is the moment: *"This effect is applied to damage at
## the END of the damage prevention step, before any effects triggered by
## the damage take place."* Bracketed as SIMULTANEOUS so two lethal blows
## are still simultaneous (CR 510.4 / 104.4b) — and so nothing dies before
## the regeneration window, which is why the bracket is left OPEN across it.
func _land_pending_damage() -> void:
	var packets := damage_pending.duplicate()
	damage_pending.clear()
	begin_simultaneous()
	for packet in packets:
		_land_damage(packet)
	# A REDIRECT during landing queues a fresh packet — `Duel.hlp`'s
	# Veteran Bodyguard ruling calls that "a second damage-prevention step
	# that follows the current one".
	if not damage_pending.is_empty():
		end_simultaneous()
		_open_priority()
		return
	if _open_regeneration_window():
		return
	end_simultaneous()
	_open_priority()


## BACKSTOP: a damage packet must never survive the turn that made it.
## Every real path lands one at the next priority (the window opens and
## closes in [method _open_priority]), but cleanup grants no priority at
## all and its damage wipe would otherwise erase a packet's victim's
## marked damage before the packet ever landed. Lands whatever is still
## waiting, redirects included, without opening a window over it — there
## is nobody left to answer one.
func _flush_stranded_damage() -> void:
	var guard := 0
	while not damage_pending.is_empty() and guard < 16:
		guard += 1
		var stranded := damage_pending.duplicate()
		damage_pending.clear()
		begin_simultaneous()
		for packet in stranded:
			_land_damage(packet)
		end_simultaneous()


## The SECOND window: `Duel.hlp`, topic **Regeneration** — *"You can use
## regeneration only at the time when a creature is about to go to the
## graveyard."* State-based actions are still deferred when this opens, so
## the doomed creatures are still on the battlefield and their controller
## can still pay.
##
## Auto-skips when nobody holds a regeneration effect, for the same reason
## the prevention window does: it is the window's only legal action.
func _open_regeneration_window() -> bool:
	if not _damage_window_armed():
		return false
	regeneration_candidates = _creatures_about_to_die()
	if regeneration_candidates.is_empty():
		return false
	var anyone := false
	for p in players:
		if _has_window_effect(p.id, false):
			anyone = true
			break
	if not anyone:
		regeneration_candidates.clear()
		return false
	awaiting_regeneration = true
	log_line("Use Regeneration Effects")   # @PROMPT_CHECKFEPHASE[11]
	return true


## Who is holding lethal damage right now and could still be saved. Zero
## toughness is NOT here: CR 704.5f is not destruction and regeneration
## cannot answer it, which is also `Duel.hlp`'s **Toughness** ruling
## ("There is no damage prevention step when toughness is lowered").
func _creatures_about_to_die() -> Array[int]:
	var out: Array[int] = []
	for inst in all_battlefield():
		if not inst.is_creature() or inst.cur_indestructible:
			continue
		if inst.regeneration_banned_this_turn:
			continue
		if inst.cur_toughness > 0 and inst.damage >= inst.cur_toughness:
			out.append(inst.id)
	return out


## Does [param pid] hold anything they could legally use in the window —
## a spell in hand or an activated ability on the battlefield whose every
## effect is of the right family? [param prevention] picks which window.
## Affordability is deliberately NOT checked: a player may tap lands
## during the step (a mana source "is neither a spell nor an effect",
## manual p.95).
func _has_window_effect(pid: int, prevention: bool) -> bool:
	for inst in players[pid].hand:
		if inst.is_land():
			continue
		if inst.data.is_modal():
			for m in inst.data.modes:
				if _effects_fit_window(m["effects"], prevention):
					return true
		elif _effects_fit_window(inst.data.spell_effects, prevention):
			return true
	for inst in players[pid].battlefield:
		for ability in inst.cur_activated_abilities:
			if _effects_fit_window(ability.effects, prevention):
				return true
	# Guardian Angel's "pay {1}: prevent 1 more" is a prevention effect the
	# seat holds without a card for it — `@GUARDIAN_EFFECT` ("Select a
	# damage card.") is the 1997 window asking for exactly this.
	if prevention and not players[pid].paid_prevention.is_empty():
		return true
	return false


## Are these effects all of the window's family, and are there any? An
## empty list is not a prevention effect — `Duel.hlp` is a whitelist, not
## a blacklist: *"No other kind of fast effects or spells are permitted."*
func _effects_fit_window(effects: Array, prevention: bool) -> bool:
	if effects.is_empty():
		return false
	for e in effects:
		if prevention:
			if not e.is_damage_prevention:
				return false
		elif not e.is_regeneration:
			return false
	return true


## THE RESTRICTED ALLOW. Every other hold-open flag in this engine is a
## blanket DENY in [method _act_precheck]; this window is the opposite
## shape, and this is the one refusal it adds. `Duel.hlp`, topic
## **Combat**, supplies the sentence.
func _damage_window_refusal(effects: Array) -> String:
	if awaiting_regeneration:
		if not _effects_fit_window(effects, false):
			return "only regeneration effects may be used now"
		return ""
	if awaiting_damage_prevention:
		if not _effects_fit_window(effects, true):
			return "no other kind of fast effects or spells are permitted " \
				+ "during damage prevention"
		return ""
	return ""


## Give [param pid] [param count] POISON counters (Marsh Viper, Pit
## Scorpion, Serpent Generator's Snakes). Ten kills, as a state-based
## action (CR 704.5c).
func add_poison(pid: int, count := 1) -> void:
	if count <= 0:
		return
	_rec(players[pid], &"poison")
	players[pid].poison += count
	log_line("%s gets %d poison counter(s) (%d total)" % [
		players[pid].player_name, count, players[pid].poison])
	check_state_based_actions()
	_emit_state()


## Move a card from OUTSIDE THE GAME into [param pid]'s hand (Ring of
## Ma'rûf). The zone is empty in a plain duel; the adventure layer fills it
## with the player's collection.
func take_from_outside_the_game(inst: CardInstance, pid: int) -> void:
	if inst == null or not players[pid].outside_the_game.has(inst):
		return
	if undo_log != null:
		_rec(players[pid], &"outside_the_game")
		_rec(players[pid], &"hand")
		_rec(inst, &"zone")
	players[pid].outside_the_game.erase(inst)
	inst.zone = Mtg.Zone.HAND
	players[pid].hand.append(inst)
	log_line("%s comes in from outside the game" % inst.data.card_name)
	_emit_state()


## Player [param pid] draws [param count] cards. Drawing from an empty
## library loses the game (CR 120.3).
func draw_cards(pid: int, count: int) -> void:
	var p := players[pid]
	for _i in count:
		# CR 614: a draw can be REPLACED before it happens (Island
		# Sanctuary, Chains of Mephistopheles, Aladdin's Lamp). A replaced
		# draw is not a draw at all — no card moves, no CARD_DRAWN event,
		# and an empty library does not kill anybody.
		if _replace_draw(pid):
			continue
		if p.library.is_empty():
			log_line("%s tries to draw from an empty library" % p.player_name)
			_lose(pid, "drew from an empty library")
			return
		if undo_log != null:
			_rec(p, &"library")
			_rec(p, &"hand")
			_rec(p, &"drawn_this_turn")
		var inst: CardInstance = p.library.pop_back()
		if undo_log != null:
			_rec(inst, &"zone")
		inst.zone = Mtg.Zone.HAND
		p.hand.append(inst)
		# "Cards drawn this turn" — Sylvan Library asks which ones, not how
		# many, so the cards themselves are kept. Cleared at cleanup.
		p.drawn_this_turn.append(inst)
		# `instance` rides along so a listener can name the card that was
		# just drawn. The 1997 Showcase does exactly that — `Duel.hlp`,
		# topic **Showcase**: *"Cards drawn into your hand are displayed
		# when you draw them."* (docs/duel-todo.md §2.14). No rules code
		# reads it; triggers still key off `player`.
		dispatch_event(Mtg.EventType.CARD_DRAWN,
			{"player": pid, "instance": inst})
	_emit_state()


# ------------------------------------------- DRAW REPLACEMENTS (CR 614) --
#
# "If you would draw a card, instead ..." is a replacement effect, and this
# is the one place every draw in the engine passes through, so it is the one
# place they are applied. Two kinds, deliberately kept apart:
#
# - STATIC ones live on a battlefield permanent (`CardData.draw_replacement`)
#   and apply for as long as it is there — Island Sanctuary, Chains of
#   Mephistopheles.
# - ONE-SHOT ones are registered by a resolving effect
#   ([method replace_next_draw]) and are consumed by the first draw they
#   catch — "the NEXT time you would draw a card this turn" (Aladdin's Lamp).
#   They expire at cleanup.
#
# CR 614.5 — a replacement effect is applied at most once to a given event —
# is what [member _draw_replacements_running] enforces: while a card's own
# replacement is running, its own "then draw a card" cannot be caught by it
# again, which is exactly Chains of Mephistopheles' printed behaviour.
#
# SIMPLIFIED (docs/ROADMAP.md): with two replacements applicable at once
# CR 616.1 gives the AFFECTED PLAYER the order; here the one-shots go first
# and the statics follow in battlefield timestamp order. The 1997 pool has
# no pair that can be on the table at the same time and disagree.

## One-shot draw replacements waiting to catch a draw. Each entry is
## {"player": int, "callback": Callable(game, pid, ctx)}.
var _one_shot_draws: Array[Dictionary] = []

## Source ids whose draw replacement is running right now (CR 614.5).
var _draw_replacements_running: Array[int] = []


## Register a ONE-SHOT draw replacement for [param pid] — "the next time
## you would draw a card this turn, instead ...". [param callback] is
## [code]func(game: MtgGame, pid: int, ctx: Dictionary)[/code] and is
## responsible for whatever happens instead (including drawing, if the card
## says so). Consumed by the first draw it catches; dropped at cleanup.
func replace_next_draw(pid: int, callback: Callable) -> void:
	_one_shot_draws.append({"player": pid, "callback": callback})


## Would-be draw number [param pid] is on within the current step, plus the
## context a replacement needs to decide. Returns true when the draw was
## replaced and must not happen.
func _replace_draw(pid: int) -> bool:
	var p := players[pid]
	_rec(p, &"draws_this_step")
	p.draws_this_step += 1
	var ctx := {
		"player": pid,
		# "during your draw step" (Island Sanctuary) / "in each of their
		# draw steps" (Chains of Mephistopheles).
		"in_draw_step": current_step() == Mtg.Step.DRAW and active_player == pid,
		"draw_number": p.draws_this_step,
	}
	for i in _one_shot_draws.size():
		var entry: Dictionary = _one_shot_draws[i]
		if int(entry["player"]) != pid:
			continue
		_one_shot_draws.remove_at(i)
		entry["callback"].call(self, pid, ctx)
		return true
	all_battlefield()   # refreshes the index below if it is stale
	# The index is built in battlefield timestamp order, which is the
	# tie-break between two statics.
	for inst in _battlefield_draw_replacements:
		if _draw_replacements_running.has(inst.id):
			continue   # CR 614.5 — once per event
		_draw_replacements_running.append(inst.id)
		var replaced: bool = inst.data.draw_replacement.call(self, inst, pid, ctx)
		_draw_replacements_running.erase(inst.id)
		if replaced:
			return true
	return false


## Is [param pid]'s draw STEP itself replaced away? ("If you would begin
## your draw step, you may skip that step instead" — Fasting.) A skipped
## step happens not at all: no draw, no DRAW_STEP event, no priority in it
## (CR 500.9 / 614.1).
func _draw_step_skipped(pid: int) -> bool:
	all_battlefield()   # refreshes the index below if it is stale
	for inst in _battlefield_draw_step_replacements:
		if inst.data.draw_step_replacement.call(self, inst, pid):
			return true
	return false


## Put a card from [param pid]'s HAND on top of their library (Sylvan
## Library's "put the card on top of your library"). Not a draw in reverse:
## nothing is shuffled and no event fires.
func put_from_hand_on_top_of_library(inst: CardInstance) -> void:
	if inst == null or inst.zone != Mtg.Zone.HAND:
		return
	var p := players[inst.owner_id]
	if not p.hand.has(inst):
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.LIBRARY)
	p.hand.erase(inst)
	inst.zone = Mtg.Zone.LIBRARY
	p.library.append(inst)
	log_line("%s puts %s on top of their library" % [
		p.player_name, inst.data.card_name])
	_emit_state()


## Put a card from [param pid]'s HAND on the BOTTOM of their library.
## Aladdin's Lamp buries the cards it did not choose.
func put_on_bottom_of_library(inst: CardInstance) -> void:
	if inst == null:
		return
	var p := players[inst.owner_id]
	_rec_move(inst, inst.owner_id, Mtg.Zone.LIBRARY)
	_remove_from_zone(inst)
	inst.zone = Mtg.Zone.LIBRARY
	p.library.insert(0, inst)
	_emit_state()


## Destroy a permanent. A regeneration shield (CR 701.15) replaces the
## destruction with: tap, clear damage, remove from combat — unless the
## destroyer says "can't be regenerated" (Terror, Wrath of God).
func destroy(inst: CardInstance, can_regenerate := true) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	# INDESTRUCTIBLE (CR 700.4): destruction simply does nothing.
	if inst.cur_indestructible:
		log_line("%s is indestructible" % inst.data.card_name)
		return
	if inst.regeneration_banned_this_turn:
		can_regenerate = false   # Hurr Jackal, Whippoorwill (CR 701.15d)
	# "The next time this permanent would be destroyed this turn, remove all
	# damage marked on it instead" (Pyramids). A replacement effect like
	# regeneration, but WITHOUT regeneration's tap and removal from combat —
	# and it is not regeneration, so "can't be regenerated" does not stop it.
	if inst.destruction_shields > 0:
		if undo_log != null:
			_rec(inst, &"destruction_shields")
			_rec(inst, &"damage")
		inst.destruction_shields -= 1
		inst.damage = 0
		log_line("%s survives — all damage is removed from it"
			% inst.data.card_name)
		recalculate()
		return
	if can_regenerate and inst.regeneration_shields > 0:
		if undo_log != null:
			_rec(inst, &"regeneration_shields")
			_rec(inst, &"tapped")
			_rec(inst, &"damage")
			undo_log.record_object(combat)   # remove_from_combat
		inst.regeneration_shields -= 1
		inst.tapped = true
		inst.damage = 0
		# CR 701.15a removes the REGENERATED creature from combat — and only
		# it. An attacker it was blocking stays blocked (CR 509.1h) and, with
		# no trample, deals no damage at all.
		remove_from_combat(inst)
		log_line("%s regenerates" % inst.data.card_name)
		# The tap must feed conditional statics (Castle) NOW, and it is a
		# real "becomes tapped" event (CR 701.15c tap → 603.2).
		recalculate()
		dispatch_event(Mtg.EventType.BECAME_TAPPED,
			{"instance": inst, "controller": inst.controller_id})
		return
	log_line("%s is destroyed" % inst.data.card_name)
	_move_to_graveyard(inst, true)


## Sacrifice a permanent (CR 701.17): straight to its owner's graveyard.
## NOT destruction — regeneration cannot replace it — but the permanent
## still DIES (dies-triggers fire). Cost payments (Strip Mine) and effects
## (Animate Dead's departing aura) both come through here.
func sacrifice_permanent(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	log_line("%s is sacrificed" % inst.data.card_name)
	_move_to_graveyard(inst, true, true)


## Forget the X a spell was cast for, as it leaves the STACK without
## becoming a permanent. CR 107.3b: the value of X in a mana cost is 0
## while the object is anywhere but the stack, so a Frankenstein's Monster
## countered after being cast for X=3 must not still be worth three corpses
## when Animate Dead raises it, and a countered Rock Hydra must not grow
## three heads. A permanent spell that RESOLVES keeps the value — its
## as-enters replacement is the one thing entitled to read it — and
## [method CardInstance.clear_battlefield_state] wipes it when that
## permanent later leaves.
func _forget_x(inst: CardInstance) -> void:
	_rec(inst, &"memory")
	inst.memory.erase("x_value")


## Counter a spell on the stack (CR 701.5a): its stack item vanishes, the
## card goes to its owner's graveyard. No effects run, no ETB happens.
func counter_spell(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.STACK:
		return
	_rec(self, &"stack")
	for i in range(stack.size() - 1, -1, -1):
		if stack[i].kind == Mtg.StackKind.SPELL and stack[i].card == inst:
			stack.remove_at(i)
			break
	log_line("%s is countered" % inst.data.card_name)
	_forget_x(inst)
	if inst.is_copy:
		# A copy of a spell is not a card: countering it makes it cease to
		# exist rather than putting a phantom card in a graveyard where
		# Regrowth or a Millstone count could find it (CR 707.10a/608.2m).
		if undo_log != null:
			_rec(inst, &"zone")
			_rec(self, &"_instances")
		inst.zone = Mtg.Zone.EXILE
		_instances.erase(inst.id)
		_emit_state()
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.GRAVEYARD)
	inst.zone = Mtg.Zone.GRAVEYARD
	players[inst.owner_id].graveyard.append(inst)
	_emit_state()


## An AURA is leaving the battlefield: unhook it from its host's
## attachment list and settle the host's fate — a stolen host goes home
## (Control Magic, Steal Artifact), a reanimated one is sacrificed
## (Animate Dead). Every exit from the battlefield runs this, not just
## destruction: bouncing or exiling the aura ends its effects too
## (CR 400.7 / 702.16-adjacent), and a stale id left in
## [code]host.attachments[/code] would keep counting for the cards that
## read that list (Rabid Wombat, Time Elemental, Ramses Overdark).
func _detach_departing_aura(inst: CardInstance) -> void:
	if not inst.data.is_aura() or inst.attached_to == -1:
		return
	var host := find_instance(inst.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	_rec(host, &"attachments")
	host.attachments.erase(inst.id)
	if inst.data.aura_steals:
		log_line("%s wears off — %s returns to its owner" % [
			inst.data.card_name, host.data.card_name])
		change_control(host, host.owner_id)
	elif inst.data.aura_reanimates:
		log_line("%s wears off — %s's controller sacrifices it" % [
			inst.data.card_name, host.data.card_name])
		# "That creature's controller sacrifices it" (modern oracle) —
		# a SACRIFICE, so regeneration can't save it.
		sacrifice_permanent(host)


## Bounce a permanent to its OWNER's hand (Unsummon). Not destruction:
## no dies-trigger, regeneration irrelevant; attached auras fall off via SBA.
func return_to_hand(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	_rec_departure(inst, inst.owner_id, Mtg.Zone.HAND)
	_detach_departing_aura(inst)
	players[inst.controller_id].battlefield.erase(inst)
	_battlefield_order.erase(inst.id)
	_battlefield_changed()
	# CR 506.4: a permanent that leaves the battlefield is removed from
	# combat. Without this a dead, bounced or anted ATTACKER kept its
	# entry and the defender could still spend a blocker on it (exile
	# and arrival were already guarded; these paths were the gap).
	combat.forget(inst.id)
	var was_controller := inst.controller_id
	var parting_memory := inst.memory.duplicate()
	var was_token := inst.is_token
	inst.clear_battlefield_state()
	inst.zone = Mtg.Zone.HAND
	# A TOKEN that would go anywhere but the battlefield ceases to exist
	# (CR 111.7): it must never become a card in a hand, where it could be
	# cast again — for free, in The Hive's case.
	if was_token:
		inst.zone = Mtg.Zone.EXILE   # nowhere, really — it stops existing
		log_line("%s ceases to exist" % inst.data.card_name)
	else:
		players[inst.owner_id].hand.append(inst)
		log_line("%s returns to %s's hand" % [
			inst.data.card_name, players[inst.owner_id].player_name])
	dispatch_event(Mtg.EventType.LEAVES_BATTLEFIELD,
		{"instance": inst, "from_controller": was_controller,
			"memory": parting_memory},
		inst)   # the departing card hears its own leave-trigger (CR 603.6d)
	if was_token:
		_instances.erase(inst.id)   # CR 111.7 — it is gone for good
	# CR 400.7: whatever comes back later is a NEW object, so drop every
	# until-end-of-turn effect still keyed to this id, and a copy stops
	# being a copy now that its own leave-trigger has been heard (707.2).
	continuous.forget_instance(inst.id)
	_run_leave_hook(inst, was_controller, parting_memory)
	inst.restore_printed_identity()
	recalculate()
	check_state_based_actions()


## Exile a permanent (Swords to Plowshares). Like bouncing, exiling is not
## destruction — no dies-trigger, no regeneration.
func exile_permanent(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	_rec_departure(inst, inst.owner_id, Mtg.Zone.EXILE)
	_detach_departing_aura(inst)
	players[inst.controller_id].battlefield.erase(inst)
	_battlefield_order.erase(inst.id)
	_battlefield_changed()
	# CR 506.4: a permanent that leaves the battlefield is removed from
	# combat — an exiled attacker can no longer be blocked, and an exiled
	# blocker stops blocking (what it blocked stays blocked, 509.1h).
	combat.forget(inst.id)
	var was_controller := inst.controller_id
	var parting_memory := inst.memory.duplicate()
	var was_token := inst.is_token
	inst.clear_battlefield_state()
	inst.zone = Mtg.Zone.EXILE
	if was_token:
		log_line("%s ceases to exist" % inst.data.card_name)   # CR 111.7
	else:
		players[inst.owner_id].exile.append(inst)
		log_line("%s is exiled" % inst.data.card_name)
	dispatch_event(Mtg.EventType.LEAVES_BATTLEFIELD,
		{"instance": inst, "from_controller": was_controller,
			"memory": parting_memory},
		inst)   # the departing card hears its own leave-trigger (CR 603.6d)
	if was_token:
		_instances.erase(inst.id)   # CR 111.7 — it is gone for good
	# CR 400.7: whatever comes back later is a NEW object, so drop every
	# until-end-of-turn effect still keyed to this id, and a copy stops
	# being a copy now that its own leave-trigger has been heard (707.2).
	continuous.forget_instance(inst.id)
	_run_leave_hook(inst, was_controller, parting_memory)
	inst.restore_printed_identity()
	recalculate()
	check_state_based_actions()


## Condemn a creature to destruction at the end of this combat
## (Cockatrice's gaze). Duplicates are harmless (destroy checks the zone).
func doom_at_end_of_combat(inst: CardInstance) -> void:
	if not _end_of_combat_doom.has(inst.id):
		_end_of_combat_doom.append(inst.id)
		log_line("%s will be destroyed at end of combat" % inst.data.card_name)


## Schedule [param action] to run once when this turn's end-of-combat step
## begins (Glyph of Doom). The action outlives its source (CR 603.7a).
## Run [param action] at the beginning of the next END STEP, whatever
## happens to whatever scheduled it — the end-step twin of
## [method schedule_end_of_combat_action] (CR 603.7a delayed triggers, which
## this stands in for; see docs/ROADMAP.md). Rakalite's "return this
## artifact to its owner's hand at the beginning of the next end step" is
## the pool's first user.
func schedule_end_step_action(action: Callable) -> void:
	_end_step_actions.append(action)


## Run [param action] at the beginning of [param pid]'s NEXT main phase
## (Mana Drain). A delayed action rather than an event, so the dispatcher's
## hot path grows nothing for a card only one spell in the pool needs.
func schedule_next_main_phase_action(pid: int, action: Callable) -> void:
	_next_main_actions.append({"player": pid, "action": action})


func schedule_end_of_combat_action(action: Callable) -> void:
	_end_of_combat_actions.append(action)


## "Whenever [param inst] is dealt damage this turn, [param controller]
## gains that much life" (Glyph of Life). [param attackers_only] narrows it
## to damage from ATTACKING creatures, which is exactly what the Glyph says.
func watch_damage_for_life(inst: CardInstance, controller: int,
		attackers_only := false) -> void:
	if inst == null:
		return
	life_on_damage_watchers.append({
		"instance_id": inst.id, "controller": controller,
		"attackers_only": attackers_only,
	})


## Permanently strip a keyword from a battlefield permanent (Elder Land
## Wurm's "loses defender") — persists through recalculations until the
## card leaves the battlefield.
func remove_keyword_permanently(inst: CardInstance, keyword: int) -> void:
	if not inst.removed_keywords.has(keyword):
		_rec(inst, &"removed_keywords")
		inst.removed_keywords.append(keyword)
	recalculate()


## Grant a keyword with NO DURATION — "and that creature gains flying"
## with nothing after it (Cocoon). It lasts for as long as the permanent
## stays on the battlefield, which is what an effect with no duration
## means (CR 611.2), and it survives the source that granted it leaving.
## For "until end of turn" use ContinuousEffects.add_until_eot_pump's
## keyword list instead.
func grant_keyword_permanently(inst: CardInstance, keyword: int) -> void:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not inst.added_keywords.has(keyword):
		_rec(inst, &"added_keywords")
		inst.added_keywords.append(keyword)
	recalculate()


## Move an AURA from the permanent it is attached to onto [param new_host]
## (CR 701.3 "attach"). This is NOT a zone change: the Aura never leaves
## the battlefield, so nothing triggers, its counters and until-end-of-turn
## effects survive, and its timestamp does not move. Kudzu hops to another
## land; Enchantment Alteration re-points someone else's Aura.
##
## Refuses silently when the Aura is not on the battlefield, when the new
## host is the current one, or when the new host is not something this Aura
## could enchant (CR 701.3d) — attachment legality asks only what the host
## IS, exactly like the state-based check.
func move_aura(aura: CardInstance, new_host: CardInstance) -> void:
	if aura == null or new_host == null:
		return
	if aura.zone != Mtg.Zone.BATTLEFIELD or new_host.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not aura.data.is_aura() or aura.attached_to == new_host.id or aura == new_host:
		return
	if aura.data.aura_target != null \
			and not aura.data.aura_target.can_attach_to(self, new_host):
		return
	var old_host := find_instance(aura.attached_to)
	if undo_log != null:
		_rec(aura, &"attached_to")
		_rec(new_host, &"attachments")
		if old_host != null:
			_rec(old_host, &"attachments")
	if old_host != null:
		old_host.attachments.erase(aura.id)
	aura.attached_to = new_host.id
	new_host.attachments.append(aura.id)
	log_line("%s moves to %s" % [aura.data.card_name, new_host.data.card_name])
	recalculate()
	check_state_based_actions()
	_emit_state()


## Put a card from [param pid]'s hand onto the battlefield FACE DOWN
## (Illusionary Mask). It arrives as a 2/2 colourless creature with no
## abilities until something turns it up.
func put_from_hand_face_down(inst: CardInstance, pid: int) -> void:
	if inst == null or inst.zone != Mtg.Zone.HAND:
		return
	if undo_log != null:
		_rec(players[inst.owner_id], &"hand")
		_rec(inst, &"face_down")
	players[inst.owner_id].hand.erase(inst)
	inst.face_down = true
	if not _put_on_battlefield(inst, pid):
		inst.face_down = false   # refused entry: it is back in the hand, face up
		return
	log_line("%s puts a masked creature onto the battlefield" % players[pid].player_name)


## Exile the top card of [param pid]'s library FACE DOWN (Knowledge
## Vault). Returns the card, or null on an empty library.
func exile_top_of_library(pid: int) -> CardInstance:
	if players[pid].library.is_empty():
		return null
	var inst: CardInstance = players[pid].library.back()
	_rec_move(inst, pid, Mtg.Zone.EXILE)
	_rec(inst, &"face_down")
	players[pid].library.pop_back()
	inst.zone = Mtg.Zone.EXILE
	inst.face_down = true
	players[pid].exile.append(inst)
	log_line("%s exiles the top card of their library face down"
		% players[pid].player_name)
	_emit_state()
	return inst


## Put an AURA from anywhere onto the battlefield attached to
## [param host] under [param controller]'s control (Takklemaggot's return).
func attach_aura_from_anywhere(aura: CardInstance, host: CardInstance,
		controller: int) -> void:
	if aura == null or host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	_remove_from_zone(aura)
	if not _put_on_battlefield(aura, controller, host):
		return   # refused entry: it went back where it came from
	log_line("%s attaches to %s" % [aura.data.card_name, host.data.card_name])
	recalculate()
	check_state_based_actions()
	_emit_state()


## Put an Aura card onto the battlefield from wherever it is "as a non-Aura
## enchantment" that "loses 'enchant creature'" (Takklemaggot's second
## clause): it enters attached to nothing, [member CardInstance.
## lost_enchant] keeps the orphaned-Aura state-based action (CR 704.5m)
## off it, and the card's own abilities tell the two states apart. Returns
## false when the entry was refused (it went back where it came from).
func return_aura_unattached(aura: CardInstance, controller: int) -> bool:
	if aura == null or not aura.data.is_aura() or aura.zone == Mtg.Zone.BATTLEFIELD:
		return false
	_remove_from_zone(aura)
	if undo_log != null: _rec(aura, &"lost_enchant")
	aura.lost_enchant = true   # before entry: nothing ever sees it as an orphan
	if not _put_on_battlefield(aura, controller):
		aura.lost_enchant = false
		return false   # refused entry: it went back where it came from
	log_line("%s returns to the battlefield as a non-Aura enchantment"
		% aura.data.card_name)
	recalculate()
	check_state_based_actions()
	_emit_state()
	return true


## Return an EXILED card to the battlefield (Tawnos's Coffin).
## [param tapped] brings it back tapped, as the Coffin says.
func return_from_exile_to_play(inst: CardInstance, controller: int,
		tapped := false) -> void:
	if inst == null or inst.zone != Mtg.Zone.EXILE:
		return
	if undo_log != null:
		_rec(players[inst.owner_id], &"exile")
		_rec(inst, &"face_down")
	players[inst.owner_id].exile.erase(inst)
	inst.face_down = false
	if not _put_on_battlefield(inst, controller):
		return   # refused entry: it stayed in exile
	if tapped:
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = true
	log_line("%s returns from exile to the battlefield" % inst.data.card_name)
	recalculate()
	_emit_state()


## Move an EXILED card into its owner's hand (Knowledge Vault's payout).
func return_from_exile_to_hand(inst: CardInstance) -> void:
	if inst == null or inst.zone != Mtg.Zone.EXILE:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.HAND)
	_rec(inst, &"face_down")
	players[inst.owner_id].exile.erase(inst)
	inst.zone = Mtg.Zone.HAND
	inst.face_down = false
	players[inst.owner_id].hand.append(inst)
	log_line("%s returns from exile to %s's hand" % [
		inst.data.card_name, players[inst.owner_id].player_name])
	_emit_state()


## Move an EXILED card into its owner's graveyard (Bronze Tablet's ransom:
## "put this card into its owner's graveyard" once both cards are already
## exiled). Rare — exile is normally one-way.
func return_from_exile_to_graveyard(inst: CardInstance) -> void:
	if inst == null or inst.zone != Mtg.Zone.EXILE:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.GRAVEYARD)
	_rec(inst, &"face_down")
	players[inst.owner_id].exile.erase(inst)
	inst.zone = Mtg.Zone.GRAVEYARD
	inst.face_down = false
	players[inst.owner_id].graveyard.append(inst)
	log_line("%s is put into its owner's graveyard" % inst.data.card_name)
	_emit_state()


## Move a card from a graveyard to exile (Cyclopean Mummy's dies-trigger,
## Sword of the Ages' payload). No trigger fires on this move in the 1997
## pool.
func exile_from_graveyard(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.GRAVEYARD:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.EXILE)
	players[inst.owner_id].graveyard.erase(inst)
	inst.zone = Mtg.Zone.EXILE
	players[inst.owner_id].exile.append(inst)
	log_line("%s is exiled from the graveyard" % inst.data.card_name)
	_emit_state()


## Tap / untap a permanent by effect (Icy Manipulator, Twiddle-style).
func tap_permanent(inst: CardInstance) -> void:
	if inst.zone == Mtg.Zone.BATTLEFIELD and not inst.tapped:
		# A face-down Illusionary Mask creature turns up rather than being
		# tapped face down (CR 708 as the card words it).
		if inst.face_down:
			turn_face_up(inst)
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = true
		log_line("%s becomes tapped" % inst.data.card_name)
		_recalculate_for_tap_change()
		dispatch_event(Mtg.EventType.BECAME_TAPPED,
			{"instance": inst, "controller": inst.controller_id})


## Untap a permanent by effect (Ley Druid, Twiddle, an Instill Energy
## untap). Fires BECAME_UNTAPPED, which Tawnos's Coffin listens for.
func untap_permanent(inst: CardInstance) -> void:
	if inst.zone == Mtg.Zone.BATTLEFIELD and inst.tapped:
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = false
		log_line("%s becomes untapped" % inst.data.card_name)
		_recalculate_for_tap_change()
		dispatch_event(Mtg.EventType.BECAME_UNTAPPED,
			{"instance": inst, "controller": inst.controller_id})


## Put the top card of [param pid]'s library into their HAND WITHOUT
## drawing it. "Puts it into their hand" is not a draw (CR 121.8), so
## nothing that watches draws sees it — Underworld Dreams stays quiet, and
## an empty library is not a loss. Returns the card, or null if there was
## none. Petra Sphinx.
func top_of_library_to_hand(pid: int) -> CardInstance:
	var p := players[pid]
	if p.library.is_empty():
		return null
	var inst: CardInstance = p.library.back()
	_rec_move(inst, p.id, Mtg.Zone.HAND)
	p.library.pop_back()
	inst.zone = Mtg.Zone.HAND
	p.hand.append(inst)
	log_line("%s puts %s into their hand" % [p.player_name, inst.data.card_name])
	_emit_state()
	return inst


## Mill: move the top [param count] cards of [param pid]'s library to
## their graveyard (Millstone). Milling out is NOT a loss — only drawing
## from an empty library is (CR 120.3); milling an empty library does
## nothing.
func mill(pid: int, count: int) -> void:
	var p := players[pid]
	for _i in count:
		if p.library.is_empty():
			return
		var inst: CardInstance = p.library.back()
		_rec_move(inst, p.id, Mtg.Zone.GRAVEYARD)
		p.library.pop_back()
		inst.zone = Mtg.Zone.GRAVEYARD
		p.graveyard.append(inst)
		log_line("%s mills %s" % [p.player_name, inst.data.card_name])
	_emit_state()


# ---------------------------------------------------------------- phasing --
# CR 702.25: a phased-out permanent is "treated as though it doesn't
# exist", but it never changed zones — so nothing triggers on the way out
# or the way in. Here that means lifting it out of the battlefield arrays
# (which every query, static and state-based action reads) and parking it
# on its controller.

## Phase [param inst] out (Oubliette). Auras attached to it go with it.
func phase_out(inst: CardInstance) -> void:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.phased_out:
		return
	for aura_id in inst.attachments.duplicate():
		var aura := find_instance(aura_id)
		if aura != null and not aura.phased_out:
			phase_out(aura)
	_rec_departure(inst)
	inst.phased_out = true
	# CR 702.25a: a phased-out permanent is treated as though it does
	# not exist, so it cannot still be an attacker or a blocker.
	combat.forget(inst.id)
	players[inst.controller_id].battlefield.erase(inst)
	_battlefield_order.erase(inst.id)
	players[inst.controller_id].phased_out.append(inst)
	_battlefield_changed()
	log_line("%s phases out" % inst.data.card_name)
	recalculate()
	check_state_based_actions()
	_emit_state()


## Phase [param inst] back in. [param tapped] taps it as it arrives
## (Oubliette's "Tap that creature as it phases in this way").
func phase_in(inst: CardInstance, tapped := false) -> void:
	if inst == null or not inst.phased_out:
		return
	if undo_log != null:
		_rec(inst, &"phased_out")
		_rec(players[inst.controller_id], &"phased_out")
		_rec(players[inst.controller_id], &"battlefield")
		_rec(self, &"_battlefield_order")
	inst.phased_out = false
	players[inst.controller_id].phased_out.erase(inst)
	players[inst.controller_id].battlefield.append(inst)
	_battlefield_order.append(inst.id)
	if tapped:
		if undo_log != null: _rec(inst, &"tapped")
		inst.tapped = true
	for aura_id in inst.attachments.duplicate():
		var aura := find_instance(aura_id)
		if aura != null and aura.phased_out:
			phase_in(aura)
	_battlefield_changed()
	log_line("%s phases in" % inst.data.card_name)
	recalculate()
	check_state_based_actions()
	_emit_state()


# ------------------------------------------------------------- face down --

## Turn [param inst] face down (Illusionary Mask): a 2/2 colourless
## creature with no name and no abilities until it is turned up.
func turn_face_down(inst: CardInstance) -> void:
	if inst == null:
		return
	_rec(inst, &"face_down")
	inst.face_down = true
	recalculate()
	check_state_based_actions()


## Turn a face-down permanent face up — what it really is, with everything
## printed on it (CR 708.4). Damage, tapping and dealing damage all do this
## to an Illusionary Mask creature.
func turn_face_up(inst: CardInstance) -> void:
	if inst == null or not inst.face_down:
		return
	_rec(inst, &"face_down")
	inst.face_down = false
	log_line("%s is turned face up" % inst.data.card_name)
	recalculate()
	check_state_based_actions()
	_emit_state()


# ---------------------------------------------------------------- copying --
# CR 707: a copy takes the COPIABLE VALUES of what it copies — everything
# printed, before any other effect. In this engine "printed" IS
# CardInstance.data, so copying is exactly repointing that reference; the
# object keeps its own id, counters, damage and controller, and
# CardInstance.printed_data restores it the moment it leaves the
# battlefield (CR 707.2).

## Make [param inst] a copy of [param source_data] (Clone, Copy Artifact,
## Vesuvan Doppelganger's upkeep). [param extra_types] is OR'd on top for
## "except it's an enchantment in addition to its other types" (Copy
## Artifact); [param keep_own_colors] leaves the copy its own colours
## (Vesuvan Doppelganger's "it doesn't copy that creature's color").
func become_copy(inst: CardInstance, source_data: CardData,
		extra_types: int = 0, keep_own_colors := false) -> void:
	if inst == null or source_data == null:
		return
	var own_colors := inst.cur_colors
	if undo_log != null:
		_rec(inst, &"data")
		_rec(inst, &"added_types")
		_rec(inst, &"color_override")
	inst.data = source_data
	inst.added_types |= extra_types
	if keep_own_colors:
		inst.color_override = own_colors
	log_line("%s becomes a copy of %s" % [
		inst.printed_data.card_name, source_data.card_name])
	# The trigger/static/cost-modifier/SBA indexes are derived from
	# `data`, so a copy made while the battlefield is otherwise unchanged
	# (Vesuvan Doppelganger's upkeep shift) has to mark them stale — else
	# the copy's abilities silently do nothing and a copied 0/0 body with a
	# characteristic-defining static dies on the spot.
	_battlefield_changed()
	recalculate()
	check_state_based_actions()
	_emit_state()


## The StackItem currently carrying [param inst], or null (Fork needs the
## spell's chosen targets and X, which live on the item, not the card).
## The ABILITY on the stack with [param ability_id], or null when it has
## already resolved or been countered — find_instance's mirror for the one
## kind of stack object that is not a card (CR 113.3b). Only ABILITY items
## answer: a triggered ability is not what "target activated ability" means.
func find_stack_ability(ability_id: int) -> StackItem:
	for item in stack:
		if item.id == ability_id and item.kind == Mtg.StackKind.ABILITY:
			return item
	return null


## COUNTER an activated ability on the stack (CR 701.5a — countering an
## ability removes it; nothing goes anywhere, because an ability is not a
## card). Costs already paid stay paid. Rust, Ayesha Tanaka.
## RETARGET a spell already on the stack: replace target slot
## [param index] with [param ref] (Reflecting Mirror's "change the target of
## target spell"). Both the flat list and the per-effect group are rewritten
## so resolution and the fizzle check agree; the new target is NOT
## re-validated against the spell's own spec, because the card that does
## this states its own requirement ("the new target must be a player").
## Returns true when a slot was actually replaced.
func retarget_spell(spell: CardInstance, index: int, ref: TargetRef) -> bool:
	var item := find_stack_item(spell)
	if item == null or index < 0 or index >= item.targets.size():
		return false
	var old_ref: TargetRef = item.targets[index]
	item.targets[index] = ref
	for group in item.target_groups:
		for i in group.size():
			if group[i].same_object(old_ref):
				group[i] = ref
	log_line("%s is redirected to %s" % [spell.data.card_name, str(ref)])
	_emit_state()
	return true


func counter_ability(ability_id: int) -> void:
	for i in range(stack.size() - 1, -1, -1):
		if stack[i].id != ability_id or stack[i].kind != Mtg.StackKind.ABILITY:
			continue
		log_line("%s is countered" % stack[i].description)
		stack.remove_at(i)
		_emit_state()
		return


func find_stack_item(inst: CardInstance) -> StackItem:
	for item in stack:
		if item.card == inst:
			return item
	return null


## Put a COPY of the spell [param spell] on the stack under
## [param controller]'s control (Fork, Chain Lightning's rider). The copy
## is not a card: it ceases to exist when it finishes resolving
## (CR 707.10a). [param new_targets] replaces the original's targets when
## non-empty; otherwise the copy keeps them — the copied spell's own
## (CR 707.10), read off its stack item, which for a spell copying ITSELF
## as it resolves is the item being resolved right now.
func copy_spell_on_stack(spell: CardInstance, controller: int,
		new_targets: Array = []) -> CardInstance:
	if spell == null:
		return null
	var original := find_stack_item(spell)
	if original == null and _resolving_item != null and _resolving_item.card == spell:
		original = _resolving_item
	if undo_log != null:
		_rec(self, &"_next_instance_id")
		_rec(self, &"_instances")
		_rec_stack_push()
	var copy := CardInstance.new(spell.data, _next_instance_id, controller)
	_next_instance_id += 1
	copy.is_copy = true
	copy.zone = Mtg.Zone.STACK
	# A copy of a spell copies the choices made when it was cast — mode,
	# X, targets AND what was paid for its additional costs (CR 707.10):
	# a forked Sacrifice adds mana for the same creature the original ate,
	# a forked Detonate still knows its X. Those live in the card-local
	# memory the caster wrote (x_value, sacrificed_mv ...) and in the stack
	# item's cost record, so both ride along.
	copy.memory = spell.memory.duplicate(true)
	_instances[copy.id] = copy
	var made := StackItem.new()
	made.kind = Mtg.StackKind.SPELL
	made.card = copy
	made.controller = controller
	made.mode = 0 if original == null else original.mode
	made.x_value = 0 if original == null else original.x_value
	if original != null:
		made.cost_paid = original.cost_paid.duplicate(true)
	var effects: Array = spell.data.spell_effects
	if spell.data.is_modal():
		effects = spell.data.modes[clampi(made.mode, 0, spell.data.modes.size() - 1)]["effects"]
	var typed: Array[EffectBase] = []
	for e in effects:
		typed.append(e)
	made.effects = typed
	var refs: Array = new_targets
	if refs.is_empty() and original != null:
		refs = original.targets
	for t in refs:
		made.targets.append(t)
	# Regroup the refs PER TARGETING EFFECT (StackItem.target_groups holds
	# one group per effect, not one per ref). A copy that keeps the
	# original's targets keeps its grouping; a copy given new ones is
	# regrouped with the same shape, so a forked Pyrotechnics still splits
	# its damage among all its targets instead of dumping the lot on the
	# first (CR 707.10c).
	if new_targets.is_empty() and original != null:
		var cloned_groups: Array = []
		for group in original.target_groups:
			cloned_groups.append((group as Array).duplicate())
		made.target_groups = cloned_groups
	elif original != null and not original.target_groups.is_empty():
		var shaped: Array = []
		var at := 0
		for group in original.target_groups:
			var size: int = (group as Array).size()
			var slice: Array = []
			for _i in size:
				if at < refs.size():
					slice.append(refs[at])
					at += 1
			shaped.append(slice)
		while at < refs.size():          # extra refs: one group each
			shaped.append([refs[at]])
			at += 1
		made.target_groups = shaped
	else:
		var groups: Array = []
		for t in refs:
			groups.append([t])
		made.target_groups = groups
	made.description = "%s copies %s" % [
		players[controller].player_name, spell.data.card_name]
	stack.append(made)
	log_line(made.description)
	_emit_state()
	return copy


## "You may choose new targets for the copy" (CR 707.10c): let
## [param pid], the copy's controller, re-aim [param copy], slot by slot.
## Each slot of each targeting effect is one question, offered every
## object legal for that slot right now (the copy is checked as if it were
## being cast, CR 115.3 / 707.10c) minus what a sibling slot of the same
## effect already took (one object per instance of "target", CR 115.3);
## the list is a CARD question when every candidate is a card and an
## OPTION list of target_label() names otherwise, ORDERED so the leading
## entry is the heuristic's answer: [param prefer_player]'s face when a
## player may be named (Fork's copy at the opponent, Chain Lightning's at
## the player who passed it on), else the old target when it is still
## legal, else the first legal one. A slot with one legal candidate is
## kept without asking; a slot with none stays as it was (the copy fizzles
## on it like any spell, CR 608.2b). The divided share of a damage ref
## rides along onto the new ref (TargetRef.with_amount).
func offer_new_targets(copy: CardInstance, pid: int, prefer_player := -1) -> void:
	var item := find_stack_item(copy)
	if item == null or item.target_groups.is_empty():
		return
	var specs := _spell_target_specs(copy.data, item.mode)
	if specs.size() != item.target_groups.size():
		return   # a shape this helper does not understand: keep the targets
	var flat_at := 0
	for i in specs.size():
		var spec: TargetSpec = specs[i]
		var group: Array = item.target_groups[i]
		var taken: Array = []   # refs already chosen for earlier slots
		for j in group.size():
			var old: TargetRef = group[j]
			var refs: Array[TargetRef] = []
			for ref in spec.legal_targets(self, copy, taken):
				var dup := false
				for t in taken:
					if t.same_object(ref):
						dup = true
						break
				if not dup:
					refs.append(ref)
			var chosen: TargetRef = old
			if refs.size() == 1:
				chosen = refs[0]
			elif refs.size() > 1:
				chosen = _ask_new_target(copy, pid, spec, refs, old, prefer_player)
			if chosen != old:
				var replaced := chosen.with_amount(old.amount) if old.amount > 0 else chosen
				_rec(item, &"targets")
				_rec(item, &"target_groups")
				item.targets[flat_at + j] = replaced
				group[j] = replaced
				log_line("%s's copy is aimed at %s" % [
					copy.data.card_name, target_label(replaced)])
				chosen = replaced
			taken.append(chosen)
		flat_at += group.size()
	_emit_state()


## One slot of [method offer_new_targets]: the ordered question and its
## answer. Never optional — a stale answer is the leading candidate.
func _ask_new_target(copy: CardInstance, pid: int, spec: TargetSpec,
		refs: Array[TargetRef], old: TargetRef, prefer_player: int) -> TargetRef:
	var lead: TargetRef = null
	if prefer_player >= 0:
		for ref in refs:
			if ref.is_player and ref.player_id == prefer_player:
				lead = ref
				break
	if lead == null:
		for ref in refs:
			if ref.same_object(old):
				lead = ref
				break
	if lead == null:
		lead = refs[0]
	var ordered: Array[TargetRef] = [lead]
	for ref in refs:
		if ref != lead:
			ordered.append(ref)
	var prompt := "%s: Select %s for the copy." % [copy.data.card_name, spec.description]
	var cards: Array[CardInstance] = []
	for ref in ordered:
		if ref.is_player or ref.is_damage or ref.is_ability:
			cards.clear()
			break
		cards.append(find_instance(ref.instance_id))
	if not cards.is_empty():
		var pick := agents[pid].choose_card(self, pid, cards, prompt, false, false, true)
		var at := cards.find(pick)
		return ordered[at] if at >= 0 else lead
	var labels: Array[String] = []
	for ref in ordered:
		labels.append(target_label(ref))
	var index := agents[pid].choose_option(self, pid, labels, prompt, 0, false, true)
	if index < 0 or index >= ordered.size():
		return lead
	return ordered[index]


# ------------------------------------------------------------------- ante --
# The 1997 game is played FOR ANTE (CR 407, and Shandalar's whole economy):
# each player stakes a card before the duel, the ante zone is public, and
# the winner takes every card in it. The opening stake is stake_ante(),
# which a driver calls AFTER setup() and BEFORE deal_opening_hands() —
# the manual's own order (p.118, "after the ante but before the shuffle").
# SETTLING the ante when the duel ends is the ADVENTURE layer's job and is
# deliberately absent here (docs/duel-todo.md §7). Cards can move into and out of the ante
# mid-game (Contract from Below, Jeweled Bird), and two of them change a
# card's OWNER permanently (Bronze Tablet, Tempest Efreet) — which is what
# decides who keeps it once the game is settled. A card lives in the ante
# array of the player who owns it.

## Every card in the ante, both players, owner order.
func all_ante() -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for p in players:
		out.append_array(p.ante)
	return out


## Move [param inst] into the ante from wherever it is. Tokens can't be
## anted (they would cease to exist, CR 704.5e).
func move_to_ante(inst: CardInstance) -> void:
	if inst == null or inst.is_token or inst.zone == Mtg.Zone.ANTE:
		return
	var was_battlefield := inst.zone == Mtg.Zone.BATTLEFIELD
	if was_battlefield:
		_rec_departure(inst, inst.owner_id, Mtg.Zone.ANTE)
		_detach_departing_aura(inst)
	else:
		_rec_move(inst, inst.owner_id, Mtg.Zone.ANTE)
	_remove_from_zone(inst)
	if was_battlefield:
		_battlefield_order.erase(inst.id)
		_battlefield_changed()   # every derived index reads the battlefield
		# CR 506.4: a permanent that leaves the battlefield is removed from
		# combat. Without this a dead, bounced or anted ATTACKER kept its
		# entry and the defender could still spend a blocker on it (exile
		# and arrival were already guarded; these paths were the gap).
		combat.forget(inst.id)
		var ante_controller := inst.controller_id
		var ante_memory := inst.memory.duplicate()
		# Same order as every other battlefield exit: wipe first (which
		# snapshots last known information, CR 608.2h), set the new zone,
		# then let the departing card hear its own leave-trigger — a
		# listener that reads the zone (Lich asks for the graveyard) must
		# see where the card went, as on every other exit.
		inst.clear_battlefield_state()
		inst.zone = Mtg.Zone.ANTE
		dispatch_event(Mtg.EventType.LEAVES_BATTLEFIELD,
			{"instance": inst, "from_controller": ante_controller,
				"memory": ante_memory}, inst)
		continuous.forget_instance(inst.id)
		_run_leave_hook(inst, ante_controller, ante_memory)
		inst.restore_printed_identity()
	inst.zone = Mtg.Zone.ANTE
	players[inst.owner_id].ante.append(inst)
	log_line("%s is put into the ante" % inst.data.card_name)
	recalculate()
	_emit_state()


## Whether this duel is played FOR ANTE — the original's `&Ante` match
## parameter (`Program/Text.res:2861`, `@SHELLPAGE_SINGLEDUEL`) and the
## manual's Gauntlet checkbox (p.138: *"ANTE is a checkbox that determines
## whether you play each duel for an ante card"*). Set by
## [method stake_ante]; nothing in the rules reads it, but the duel screen
## and the adventure layer do — a duel that was not played for ante has
## nothing to settle when it ends.
##
## OFF unless something stakes. An ante is a card LIFTED OUT OF A LIBRARY
## and one RNG draw spent, so every caller that does not ask for one — the
## Deck Lab, the AI benchmarks, `start()`, every headless test — keeps the
## exact shuffle and the exact opening hand it had before ante existed.
var ante_enabled := false


## STAKE THE OPENING ANTE: [param count] cards out of [param pid]'s deck,
## into the ante zone, before the opening hands are dealt. Returns what was
## staked (empty if the library could not supply it).
##
## THE MANUAL, p.60: *"Before the duel begins, both players put up one or
## more cards from their decks as ante. In Shandalar, whoever wins the duel
## will get to keep the ante cards."* One card each is the default because
## the original's own option is singular — *"whether you play each duel for
## AN ANTE CARD"* (p.138) — while `count` stays open because the manual says
## "one or more" and the Challenge screen offers *"the card (or one of the
## cards) you stand to win"* (p.42).
##
## WHEN, exactly: the ante comes off the deck BEFORE the shuffle. The manual
## pins the order in passing, describing the minimum-deck padding as random
## basic lands added to your library *"(after the ante but before the
## shuffle)"* (p.118). We shuffle in [method setup], so this picks a
## UNIFORMLY RANDOM card out of the already-shuffled library instead —
## distributionally identical to drawing one from the unshuffled deck and
## shuffling the rest, and one `rng` draw either way.
##
## [param exclude_basic_lands] is SHANDALAR'S OWN KINDNESS, and it applies
## to the player's stake only: the FAQ's question 1.9, *"Why don't I ante
## basic lands? Basic lands are too weak a card to ante"* — while the
## creature you are duelling may perfectly well put up a Mountain, as the
## owner's 1997 screenshot shows Cromer doing. Only BASIC lands are spared;
## a Strip Mine or a Library of Alexandria is a real card and a real stake.
## A deck with nothing but basic lands falls back to them rather than
## refusing to stake (the original loses that duel outright — FAQ 1.9 —
## which is an adventure-layer verdict, not a rules one).
##
## Deterministic: `rng` only, per the engine's contract.
func stake_ante(pid: int, count := 1, exclude_basic_lands := false) -> Array[CardInstance]:
	var staked: Array[CardInstance] = []
	if pid < 0 or pid >= players.size() or count <= 0:
		return staked
	var p := players[pid]
	for _i in count:
		var pool: Array[CardInstance] = []
		if exclude_basic_lands:
			for inst in p.library:
				if not (inst.data.supertypes & Mtg.Supertype.BASIC):
					pool.append(inst)
		if pool.is_empty():
			pool.assign(p.library)
		if pool.is_empty():
			break
		var picked: CardInstance = pool[rng.randi_range(0, pool.size() - 1)]
		_rec_move(picked, pid, Mtg.Zone.ANTE)
		p.library.erase(picked)
		picked.zone = Mtg.Zone.ANTE
		p.ante.append(picked)
		staked.append(picked)
		log_line("%s antes %s" % [p.player_name, picked.data.card_name])
	if not staked.is_empty():
		_rec(self, &"ante_enabled")
		ante_enabled = true
		_emit_state()
	return staked


## Ante the top card of [param pid]'s library (Contract from Below,
## Demonic Attorney, Rebirth). Returns the card, or null on an empty library.
func ante_top_of_library(pid: int) -> CardInstance:
	var p := players[pid]
	if p.library.is_empty():
		return null
	var inst: CardInstance = p.library.back()
	_rec_move(inst, inst.owner_id, Mtg.Zone.ANTE)
	p.library.pop_back()
	inst.zone = Mtg.Zone.ANTE
	players[inst.owner_id].ante.append(inst)
	log_line("%s antes %s from the top of their library" % [
		p.player_name, inst.data.card_name])
	_emit_state()
	return inst


## Take [param inst] out of the ante into [param to_zone] (Jeweled Bird
## dumps the ante into a graveyard; Darkpact pulls one back onto a library).
func remove_from_ante(inst: CardInstance, to_zone: int) -> void:
	if inst == null or inst.zone != Mtg.Zone.ANTE:
		return
	_rec_move(inst, inst.owner_id, to_zone)
	players[inst.owner_id].ante.erase(inst)
	inst.zone = to_zone
	match to_zone:
		Mtg.Zone.GRAVEYARD: players[inst.owner_id].graveyard.append(inst)
		Mtg.Zone.HAND:      players[inst.owner_id].hand.append(inst)
		Mtg.Zone.EXILE:     players[inst.owner_id].exile.append(inst)
		Mtg.Zone.LIBRARY:   players[inst.owner_id].library.append(inst)
		_:
			inst.zone = Mtg.Zone.ANTE
			players[inst.owner_id].ante.append(inst)
			return
	log_line("%s leaves the ante" % inst.data.card_name)
	_emit_state()


## PERMANENT change of ownership (Bronze Tablet, Tempest Efreet, Darkpact).
## The card physically moves to the new owner's copy of its current zone —
## an owner change is the one thing that outlives the duel.
func change_owner(inst: CardInstance, new_owner: int) -> void:
	if inst == null or inst.owner_id == new_owner or inst.is_token:
		return
	var zone := inst.zone
	if undo_log != null:
		_rec(inst, &"owner_id")
		_rec(inst, &"controller_id")
		var field: StringName = ZONE_FIELD.get(zone, &"")
		if field != &"":
			_rec(players[new_owner], field)
	_remove_from_zone(inst)
	inst.owner_id = new_owner
	if zone != Mtg.Zone.BATTLEFIELD:
		inst.controller_id = new_owner
	match zone:
		Mtg.Zone.ANTE:       players[new_owner].ante.append(inst)
		Mtg.Zone.GRAVEYARD:  players[new_owner].graveyard.append(inst)
		Mtg.Zone.HAND:       players[new_owner].hand.append(inst)
		Mtg.Zone.EXILE:      players[new_owner].exile.append(inst)
		Mtg.Zone.LIBRARY:    players[new_owner].library.append(inst)
		Mtg.Zone.BATTLEFIELD:
			players[inst.controller_id].battlefield.append(inst)
	log_line("%s now owns %s" % [players[new_owner].player_name, inst.data.card_name])
	_emit_state()


## Pull [param inst] out of whichever zone array currently holds it. Does
## not touch inst.zone, and does not touch the battlefield TIMESTAMP order
## (a change of owner keeps a permanent's place in it) — callers that
## really move a card off the battlefield clear that themselves.
## Zone -> the [MtgPlayer] array that holds a card in it. Used by the search
## journal to record exactly the one list a zone change disturbs.
## Mtg.Zone.STACK is absent on purpose: the stack lives on the game.
const ZONE_FIELD := {
	Mtg.Zone.LIBRARY: &"library",
	Mtg.Zone.HAND: &"hand",
	Mtg.Zone.BATTLEFIELD: &"battlefield",
	Mtg.Zone.GRAVEYARD: &"graveyard",
	Mtg.Zone.EXILE: &"exile",
	Mtg.Zone.ANTE: &"ante",
}


func _remove_from_zone(inst: CardInstance) -> void:
	if undo_log != null:
		# Record only the array the card is actually leaving. Recording all
		# six a side was measured at a third of a node's cost on a wide
		# board, because a duplicate of an 80-permanent battlefield is not
		# free. An unknown zone falls back to all of them.
		var field: StringName = ZONE_FIELD.get(inst.zone, &"")
		for p in players:
			if field != &"":
				undo_log.record(p, field, p.get(field))
			else:
				for f in ZONE_FIELD.values():
					undo_log.record(p, f, p.get(f))
	for p in players:
		p.library.erase(inst)
		p.hand.erase(inst)
		p.graveyard.erase(inst)
		p.exile.erase(inst)
		p.ante.erase(inst)
		p.battlefield.erase(inst)


## Replace one seat's DecisionAgent (the AI registers itself here).
func set_agent(pid: int, agent: DecisionAgent) -> void:
	agents[pid] = agent


## Discard specific cards from [param pid]'s hand (agent-chosen discards).
## [param by_effect] says a spell or ability's EFFECT is doing the
## discarding — the default, and what almost every caller is. The
## exceptions pass false: a discard paid as a COST (Land's Edge, Jandor's
## Ring — CR 601.2h, no effect has resolved) and the cleanup step's
## hand-size discard (a turn-based action, CR 514.1). The distinction is
## Library of Leng's: only an effect's discard may go to the top of the
## library instead ([method _discard_to_library_instead]).
func discard_cards(pid: int, cards: Array, by_effect := true) -> void:
	var p := players[pid]
	var fired: Array[CardInstance] = []
	for inst in cards:
		if inst == null or not p.hand.has(inst):
			continue
		if inst.data.on_discarded.is_valid():
			fired.append(inst)
		if _discard_to_library_instead(pid, inst, by_effect):
			_announce_discard(pid, inst, by_effect, true)
			continue
		_rec_move(inst, pid, Mtg.Zone.GRAVEYARD)
		p.hand.erase(inst)
		inst.zone = Mtg.Zone.GRAVEYARD
		p.graveyard.append(inst)
		log_line("%s discards %s" % [p.player_name, inst.data.card_name])
		_announce_discard(pid, inst, by_effect, false)
	_emit_state()
	# After the whole discard, so a card that punishes the discarder sees a
	# settled hand (CR 603.2 — the ability triggers on the event, and every
	# card in one instruction leaves together).
	for inst in fired:
		inst.data.on_discarded.call(self, inst, pid, _resolving_controller)


## Search [param pid]'s library for a card matching [param filter] (their
## agent chooses among candidates), put it into their hand, shuffle.
## Null filter = any card. The searching player sees their whole library
## (CR 701.19b) — candidates are the real list.
## [param to_battlefield]: the found card enters the battlefield instead of
## the hand (Untamed Wilds) — via _put_on_battlefield, so ETB rules
## (summoning sickness, enters-tapped, triggers) all apply.
## Search [param pid]'s library for a card matching [param filter] and
## REMOVE it, shuffling afterwards — the caller decides where it goes
## (Transmute Artifact puts it onto the battlefield or buries it depending
## on a payment). Returns null when nothing is found.
func pick_from_library(pid: int, filter: Callable, prompt: String) -> CardInstance:
	var p := players[pid]
	var candidates: Array[CardInstance] = []
	for inst in p.library:
		if not filter.is_valid() or filter.call(inst):
			candidates.append(inst)
	var chosen := agents[pid].choose_card(self, pid, candidates, prompt, true)
	# The library is rewritten on BOTH paths — the pick leaves it and the
	# shuffle reorders it — so it is journaled once here, as
	# search_library does; the card's own zone is recorded by whichever
	# helper the caller then puts it somewhere with (2026-09-02).
	_rec(p, &"library")
	if chosen == null or not p.library.has(chosen):
		log_line("%s searches their library and finds nothing" % p.player_name)
		_shuffle(p.library)
		_emit_state()
		return null
	p.library.erase(chosen)
	log_line("%s searches their library and finds %s" % [
		p.player_name, chosen.data.card_name])
	_shuffle(p.library)
	_emit_state()
	return chosen


## Put a card that is currently in NO zone array (just picked out of a
## library) onto the battlefield under [param controller].
func put_into_play(inst: CardInstance, controller: int) -> void:
	if inst == null:
		return
	_put_on_battlefield(inst, controller)


## Put a card from a player's HAND onto the battlefield without casting it
## (Eureka, Gaea's Touch, Triassic Egg, Goblin Wizard). The card leaves the
## hand first — [method put_into_play] alone expects a card that is already
## out of every zone array, and leaving it in the hand would let the same
## card be offered twice.
func put_from_hand_into_play(inst: CardInstance, controller: int) -> void:
	if inst == null or inst.zone != Mtg.Zone.HAND:
		return
	# _put_on_battlefield journals the ARRIVAL; the hand it leaves is this
	# helper's to record, or an unwind puts the card's zone back to HAND
	# with no hand holding it — a phantom (2026-09-02).
	_rec_move(inst, controller, Mtg.Zone.BATTLEFIELD)
	players[inst.owner_id].hand.erase(inst)
	_put_on_battlefield(inst, controller)


## Put a card that was just picked out of a library into its owner's
## graveyard (Transmute Artifact's unpaid difference).
func put_into_graveyard(inst: CardInstance) -> void:
	if inst == null:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.GRAVEYARD)
	inst.zone = Mtg.Zone.GRAVEYARD
	players[inst.owner_id].graveyard.append(inst)
	log_line("%s is put into its owner's graveyard" % inst.data.card_name)
	_emit_state()


## Search [param pid]'s library for a card matching [param filter], put it
## into their hand (or, with [param to_battlefield], onto the battlefield
## through the full ETB path), then shuffle. The searching player's agent
## chooses among the real candidates — they see their whole library
## (CR 701.19b) — and "fail to find" is legal, so a null choice is honoured.
## [param shuffle_after] false leaves the library UNSHUFFLED for a caller
## that searches several times and shuffles once at the end (Land Tax's
## "up to three basic land cards ... then shuffle" — CR 701.19a puts the
## shuffle after the whole search); it then owes [method shuffle_library].
func search_library(pid: int, filter: Callable, prompt: String,
		to_battlefield := false, shuffle_after := true) -> void:
	var p := players[pid]
	var candidates: Array[CardInstance] = []
	for inst in p.library:
		if not filter.is_valid() or filter.call(inst):
			candidates.append(inst)
	var chosen := agents[pid].choose_card(self, pid, candidates, prompt, true)
	if chosen != null and p.library.has(chosen):
		_rec_move(chosen, pid, Mtg.Zone.HAND)
		p.library.erase(chosen)
		log_line("%s searches their library and finds %s" % [
			p.player_name, chosen.data.card_name])
		if to_battlefield:
			_put_on_battlefield(chosen, pid)
		else:
			chosen.zone = Mtg.Zone.HAND
			p.hand.append(chosen)
	else:
		log_line("%s searches their library and finds nothing" % p.player_name)
	if shuffle_after:
		_rec(p, &"library")
		_shuffle(p.library)
	_emit_state()


## Discard [param pid]'s whole hand (Wheel of Fortune). An effect's
## discard, so with a Library of Leng each card may go to the top of the
## library instead — the Library + Wheel trick that keeps a hand, the 1997
## help's own example of a discard the Library catches.
func discard_hand(pid: int) -> void:
	var p := players[pid]
	if undo_log != null:
		_rec(p, &"hand")
		_rec(p, &"graveyard")
		for inst in p.hand:
			_rec(inst, &"zone")
	while not p.hand.is_empty():
		var inst: CardInstance = p.hand[-1]
		if _discard_to_library_instead(pid, inst, true):
			_announce_discard(pid, inst, true, true)
			continue
		p.hand.pop_back()
		inst.zone = Mtg.Zone.GRAVEYARD
		p.graveyard.append(inst)
		_announce_discard(pid, inst, true, false)
	log_line("%s discards their hand" % p.player_name)
	_emit_state()


## One card has left [param pid]'s hand as a discard — say so on the
## event bus ([constant Mtg.EventType.CARD_DISCARDED]), for the table's
## ear. After the move, never before: a listener that reads the card's
## zone must see where it went.
func _announce_discard(pid: int, inst: CardInstance, by_effect: bool,
		to_library: bool) -> void:
	dispatch_event(Mtg.EventType.CARD_DISCARDED, {
		"player": pid, "instance": inst,
		"by_effect": by_effect, "to_library": to_library})


## Library of Leng's second half (CR 614.1a-style "instead"): with
## [member MtgPlayer.discard_to_library_top] set and an EFFECT doing the
## discarding, the discarder is asked whether [param inst] goes to the top
## of their library instead of the graveyard. Returns true when it did —
## the card has left the hand and is on top of the library; the caller
## skips its own graveyard move. It is STILL a discard ("you are still
## discarding, just to your library" — Duel.hlp, Library of Leng), so the
## card's on-discard trigger fires either way.
##
## Hint: a spell is worth drawing again next turn, a land is not.
func _discard_to_library_instead(pid: int, inst: CardInstance,
		by_effect: bool) -> bool:
	var p := players[pid]
	if not by_effect or not p.discard_to_library_top:
		return false
	var keep := agents[pid].choose_yes_no(self, pid,
		"Library of Leng: Put %s on top of your library instead of into your graveyard?"
			% inst.data.card_name, not inst.is_land())
	if not keep:
		return false
	_rec_move(inst, pid, Mtg.Zone.LIBRARY)
	p.hand.erase(inst)
	inst.zone = Mtg.Zone.LIBRARY
	p.library.append(inst)
	log_line("%s discards %s to the top of their library" % [
		p.player_name, inst.data.card_name])
	return true


## Shuffle [param pid]'s hand and graveyard into their library
## (Timetwister's per-player reset). The caller draws afterwards.
func shuffle_hand_and_graveyard_into_library(pid: int) -> void:
	var p := players[pid]
	if undo_log != null:
		_rec(p, &"hand")
		_rec(p, &"graveyard")
		_rec(p, &"library")
		for inst in p.hand:
			_rec(inst, &"zone")
		for inst in p.graveyard:
			_rec(inst, &"zone")
	for inst in p.hand:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	for inst in p.graveyard:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.hand.clear()
	p.graveyard.clear()
	_shuffle(p.library)
	log_line("%s shuffles hand and graveyard into their library" % p.player_name)
	_emit_state()


## Move a creature card from a graveyard to its owner's hand (Raise Dead).
func return_from_graveyard_to_hand(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.GRAVEYARD:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.HAND)
	players[inst.owner_id].graveyard.erase(inst)
	inst.zone = Mtg.Zone.HAND
	players[inst.owner_id].hand.append(inst)
	log_line("%s returns from the graveyard to %s's hand" % [
		inst.data.card_name, players[inst.owner_id].player_name])
	_emit_state()


## Move a card from a graveyard to the TOP of its owner's library
## (Drafna's Restoration, Ring of Ma'rûf's cousins). The card keeps no
## battlefield state — it never had any in the graveyard.
func return_from_graveyard_to_library_top(inst: CardInstance) -> void:
	if inst.zone != Mtg.Zone.GRAVEYARD:
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.LIBRARY)
	players[inst.owner_id].graveyard.erase(inst)
	inst.zone = Mtg.Zone.LIBRARY
	# The library's TOP is the END of the array (draw_cards pops the back),
	# so cards land on top in the order they are handed to this method.
	players[inst.owner_id].library.append(inst)
	log_line("%s goes on top of %s's library" % [
		inst.data.card_name, players[inst.owner_id].player_name])
	_emit_state()


## Discard [param count] cards at random from [param pid]'s hand
## (Hypnotic Specter). Uses the game RNG — deterministic under a seed.
## [param by_effect] as in [method discard_cards]: a random discard paid as
## a cost passes false and Library of Leng stays out of it.
func discard_random(pid: int, count := 1, by_effect := true) -> void:
	var p := players[pid]
	for _i in count:
		if p.hand.is_empty():
			return
		var idx := rng.randi_range(0, p.hand.size() - 1)
		var inst: CardInstance = p.hand[idx]
		log_line("%s discards %s at random" % [p.player_name, inst.data.card_name])
		var to_library := _discard_to_library_instead(pid, inst, by_effect)
		if not to_library:
			_rec_move(inst, pid, Mtg.Zone.GRAVEYARD)
			p.hand.remove_at(idx)
			inst.zone = Mtg.Zone.GRAVEYARD
			p.graveyard.append(inst)
		_announce_discard(pid, inst, by_effect, to_library)
		if inst.data.on_discarded.is_valid():
			inst.data.on_discarded.call(self, inst, pid, _resolving_controller)
	_emit_state()


## Gain/lose life outside of damage.
func adjust_life(pid: int, delta: int) -> void:
	# "If you would gain life, draw that many cards instead" (Lich) — a
	# REPLACEMENT effect, so no life is gained at all.
	if delta > 0 and players[pid].life_gain_becomes_draw:
		log_line("%s draws %d instead of gaining life" % [
			players[pid].player_name, delta])
		draw_cards(pid, delta)
		return
	if undo_log != null: _rec(players[pid], &"life")
	players[pid].life += delta
	log_line("%s %s %d life (now %d)" % [players[pid].player_name,
		"gains" if delta >= 0 else "loses", absi(delta), players[pid].life])
	check_state_based_actions()


# --------------------------------------------------------------- internals --

## Common refusals shared by every priority action.
func _act_precheck(pid: int) -> String:
	if game_over:
		return "the game is over"
	if pid < 0 or pid >= players.size():
		return "no such player"
	if awaiting_attackers:
		return "waiting for attackers to be declared"
	if awaiting_blockers:
		return "waiting for blockers to be declared"
	if awaiting_discard:
		return "waiting for the discard phase to be answered"
	if awaiting_damage_assignment:
		return "waiting for combat damage to be assigned"
	if awaiting_choice != null:
		return "waiting for a choice to be made"
	return ""


func _spell_target_specs(data: CardData, mode := 0) -> Array[TargetSpec]:
	# Auras target what they will enchant (CR 303.4a).
	if data.is_aura():
		var specs: Array[TargetSpec] = [data.aura_target]
		return specs
	var specs: Array[TargetSpec] = []
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	for e in effects:
		if e.target_spec != null:
			specs.append(e.target_spec)
	return specs


# -------------------------------------------------------- triggered payments --
# "You may pay {N}" / "unless you pay" costs resolved MID-TRIGGER (the
# lucky charms, Phantasmal Forces, Mana Vault, Paralyze) — mage-go's
# TryPayMana. Floating mana is used first; what's missing is produced by
# auto-tapping the player's untapped lands (through tap_for_mana, so mana
# triggers and became-tapped triggers all fire). SIMPLIFIED (engine-wide,
# docs/ROADMAP.md): only LANDS are auto-tapped — artifact mana must be
# floated beforehand — and the engine's greedy pick (basics before
# multi-option lands) decides which lands tap.

## Can [param pid] cover [param cost] right now? (Pure check — the hint
## for choose_yes_no offers.)
func can_afford_cost(pid: int, cost: ManaCost) -> bool:
	return _payment_plan(pid, cost) != null


## Attempt to actually pay [param cost]. Returns true and pays, tapping
## lands as needed. Returns false when no plan covers the cost (nothing is
## touched) — or, should a plan go stale mid-execution, it stops tapping at
## the first refusal and reports failure with the mana already produced
## still floating (it empties at the end of the step, CR 500.4).
func try_pay(pid: int, cost: ManaCost) -> bool:
	var plan: Variant = _payment_plan(pid, cost)
	if plan == null:
		return false
	for step in plan:
		if tap_for_mana(pid, step[0], step[1]) != "":
			break   # the plan went stale — stop before tapping more
	if not players[pid].mana_pool.can_pay(cost):
		return false   # a tap trigger disturbed the pool — refuse safely
	players[pid].mana_pool.pay(cost)
	log_line("%s pays %s" % [players[pid].player_name,
		cost.text if cost.text != "" else "{0}"])
	_emit_state()
	return true


## Build the tap plan covering [param cost]: Array of [land, ability_index]
## pairs, [] if floating mana already suffices, or null if uncoverable.
func _payment_plan(pid: int, cost: ManaCost) -> Variant:
	var p := players[pid]
	var sim := ManaPool.new()
	for c in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
			Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
		var have := p.mana_pool.amount_of(c)
		if have > 0:
			sim.add(c, have)
	# LIVE mana abilities, never the printed list: under Blood Moon /
	# Conversion / Evil Presence a land taps for something else entirely,
	# and tap_for_mana indexes cur_mana_abilities — a plan built from
	# data.mana_abilities would tap for the wrong colour (or index out of
	# range) and pay nothing.
	var lands: Array[CardInstance] = []
	for inst in p.battlefield:
		if inst.is_land() and not inst.tapped \
				and _has_free_mana_ability(inst) \
				and not (inst.is_creature() and inst.summoning_sick):
			lands.append(inst)
	lands.sort_custom(_fewer_mana_options)   # basics before duals/City
	var plan: Array = []
	# Colored requirements first — each taken from a land producing it.
	for color in cost.colored:
		while sim.amount_of(color) < cost.colored[color]:
			var found := false
			for li in lands.size():
				var idx := _ability_producing(lands[li], color)
				if idx != -1:
					plan.append([lands[li], idx])
					# produce_into_for honours dynamic amounts (the Urza
					# lands give two once the Tron is assembled).
					lands[li].cur_mana_abilities[idx].produce_into_for(sim, self, lands[li])
					lands.remove_at(li)
					found = true
					break
			if not found:
				return null
	# Generic remainder from whatever is left.
	while not sim.can_pay(cost):
		if lands.is_empty():
			return null
		var land: CardInstance = lands.pop_front()
		var idx := _first_free_mana_ability(land)
		plan.append([land, idx])
		land.cur_mana_abilities[idx].produce_into_for(sim, self, land)
	return plan


## Can [param ability] be activated by the auto-tapper for nothing but the
## {T}? Mana abilities with their own mana/life/sacrifice riders (Standing
## Stones, Black Lotus) are off limits: try_pay would silently pay those
## extra costs, and the plan's arithmetic does not model them.
static func _is_free_mana_ability(ability: ManaAbility) -> bool:
	return ability.taps_source and ability.cost == null and ability.life_cost == 0 \
		and ability.counter_cost_kind == "" \
		and not ability.sacrifice_source and not ability.sacrifice_filter.is_valid()


static func _has_free_mana_ability(inst: CardInstance) -> bool:
	return _first_free_mana_ability(inst) != -1


static func _first_free_mana_ability(inst: CardInstance) -> int:
	for i in inst.cur_mana_abilities.size():
		if _is_free_mana_ability(inst.cur_mana_abilities[i]):
			return i
	return -1


static func _fewer_mana_options(a: CardInstance, b: CardInstance) -> bool:
	return a.cur_mana_abilities.size() < b.cur_mana_abilities.size()


func _ability_producing(inst: CardInstance, color: int) -> int:
	for i in inst.cur_mana_abilities.size():
		var ability: ManaAbility = inst.cur_mana_abilities[i]
		if not _is_free_mana_ability(ability):
			continue
		# A dynamic-colour source (Gem Bazaar) makes the colour it is
		# SHOWING, not the seed colour it was built with — otherwise a blue
		# Bazaar could not pay a {U} upkeep and Stasis was sacrificed with
		# the mana sitting right there.
		if ability.dynamic_color.is_valid():
			if int(ability.dynamic_color.call(self, inst)) == color:
				return i
			continue
		for pair in ability.produces:
			if pair[0] == color:
				return i
	return -1


# ------------------------------------------------------------ cost modifiers --
# Battlefield permanents may tax spells or abilities (Gloom). The AI's mana
# planner calls these too, so plans and payments always agree.

## Could [param pid] pay for [param data] out of their floating mana right
## now? Applies everything cast_spell applies — cost modifiers under the
## CR 601.2f floor, restricted mana, colour substitutions and North Star's
## charge — so a UI castability hint cannot drift from what cast_spell
## will actually accept. An {X} spell is priced at X=0, the cheapest it
## can be cast for. Payability ONLY: timing, priority and legal targets
## remain the caller's business.
func can_afford(pid: int, data: CardData) -> bool:
	var surcharge: int = maxi(spell_surcharge(pid, data), -data.cost.generic)
	var usage := mana_usage_keys(data)
	var subs: Array = players[pid].mana_substitutions
	var pool: ManaPool = players[pid].mana_pool
	if pool.can_pay(data.cost, surcharge, usage, subs):
		return true
	return players[pid].any_color_spells > 0 \
		and pool.can_pay(data.cost, surcharge, usage, subs, true)


## THE POTENTIAL-MANA COMPANION of [method can_afford]: could [param pid]
## cast [param data] if they tapped what they still have UNTAPPED? An {X}
## spell is priced at X=0, as `can_afford` prices it.
##
## `docs/ROADMAP.md` has asked for this query since the duel screen's Done
## order was written ("No POTENTIAL-mana query… the castable highlight and
## the AI planner want the same thing"), and the 1997 screen needs it to
## mean what it says: `Duel.hlp`, topic **Hands**, *"At any given time,
## some, all, or none of the cards in your hand might be useable. Just for
## starters, you must have enough MANA AVAILABLE… When all the necessary
## conditions are met, a card in your hand is useable, and therefore will
## be highlighted as such."* In a game that auto-tapped, *"mana available"*
## is untapped sources, not a floating pool.
##
## Payability ONLY, exactly like [method can_afford]: timing, priority and
## legal targets remain the caller's business. [param excluded] is the
## `Don't auto tap this card` set — see [method ManaPlanner.sources].
##
## SIMPLIFIED: colour SUBSTITUTIONS (Sunglasses of Urza) and North Star's
## any-type charge widen only the FLOATING half of the answer, because
## `can_afford` is asked first and the planner models neither. It therefore
## under-reports for those two cards and never over-reports, which is the
## safe direction for a highlight. (docs/ROADMAP.md)
func could_afford(pid: int, data: CardData, excluded: Dictionary = {}) -> bool:
	if can_afford(pid, data):
		return true
	var surcharge: int = maxi(spell_surcharge(pid, data), -data.cost.generic)
	return not ManaPlanner.plan(self, pid, data.cost, surcharge,
		mana_usage_keys(data), excluded).is_empty()


## Is [param refusal] the "you have not paid for it yet" answer — the one
## refusal a front end can fix by tapping another land, rather than by
## giving up on the action? Both [method cast_spell]'s and
## [method activate_ability]'s mana refusals begin with these words, and
## nothing else in this file does.
##
## The duel screen needs the distinction because 1997's casting flow puts
## the payment AFTER the click: *"Click on it to cast it. You're prompted
## to provide mana to pay the casting cost"* (`Duel.hlp`, topic
## **Spells**), so an unpaid cast is a cast in progress, not a mistake.
static func is_unpaid_refusal(refusal: String) -> bool:
	return refusal.begins_with("not enough mana")


## WHAT A CAST ACTUALLY COSTS, as three numbers: `{"cost": ManaCost,
## "extra": int, "surcharge": int, "usage": Array}` — exactly what
## [method cast_spell] hands `ManaPool.can_pay`, and it hands them over
## from HERE, so an auto-tapper planning the payment and the engine
## demanding it can never disagree.
##
## `cost` is the printed cost resolved for [param x_value] (CR 601.2f);
## `extra` is the generic on top of it (the X that pays as generic, plus
## cost modifiers, plus Fireball's per-target charge); `surcharge` is the
## modifier half of `extra` on its own, which is the only part the refusal
## message names; `usage` is the restricted-mana keys the spell qualifies
## for ("artifact" for an artifact spell). [param target_count] is how many
## targets the cast ended up with.
##
## Cost reductions can never eat into the coloured part of a cost, so the
## surcharge is clamped at minus the printed generic PLUS what X
## contributed — a Mana Matrix really does make a Howl from Beyond for X=3
## cost {1}{B}.
func spell_payment(pid: int, data: CardData, x_value := 0,
		target_count := 1) -> Dictionary:
	var x_paid: int = 0 if data.x_color != 0 else x_value * data.cost.x_count
	var surcharge: int = maxi(spell_surcharge(pid, data),
		-(data.cost.generic + x_paid))
	if data.extra_cost_per_target > 0:
		surcharge += data.extra_cost_per_target * maxi(target_count - 1, 0)
	return {
		"cost": data.cost_for(x_value),
		"extra": x_paid + surcharge,
		"surcharge": surcharge,
		"usage": mana_usage_keys(data),
	}


## [method spell_payment] for an activated ability. Abilities never qualify
## for "spend this only to CAST …" mana, so `usage` is always empty, and
## the generic X is folded into `extra` and into `surcharge` together —
## which is what the ability's own refusal message has always reported.
func ability_payment(pid: int, inst: CardInstance, index: int,
		x_value := 0) -> Dictionary:
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var ability_x: int = 0 if ability.x_color != 0 else x_value * ability.cost.x_count
	var surcharge: int = maxi(ability_surcharge(pid, inst),
		-(ability.cost.generic + ability_x)) + ability_x
	return {
		"cost": ability.cost_for(x_value),
		"extra": surcharge,
		"surcharge": surcharge,
		"usage": [] as Array,
	}


## Total extra GENERIC mana [param pid] must pay to cast [param data] now.
## PERFORMANCE: the AI asks this once per castable card per decision, so it
## walks only the permanents that actually carry a cost modifier (usually
## none) instead of the whole battlefield.
func spell_surcharge(pid: int, data: CardData) -> int:
	all_battlefield()   # refresh the index if the battlefield moved
	if _battlefield_cost_modifiers.is_empty():
		return 0
	var total := 0
	for inst in _battlefield_cost_modifiers:
		var cb: Callable = inst.data.cost_modifier.get("spell", Callable())
		if cb.is_valid():
			# The MODIFIER is passed its own source, so "spells YOU cast"
			# means the source's controller. Without it every Mana Matrix on
			# the board scanned for any Matrix and two opposing copies
			# doubled each other's discount.
			total += int(cb.call(self, pid, data, inst))
	return total


## Total extra GENERIC mana [param pid] must pay to activate an ability of
## [param source] now.
func ability_surcharge(pid: int, source: CardInstance) -> int:
	all_battlefield()
	if _battlefield_cost_modifiers.is_empty():
		return 0
	var total := 0
	for inst in _battlefield_cost_modifiers:
		var cb: Callable = inst.data.cost_modifier.get("ability", Callable())
		if cb.is_valid():
			total += int(cb.call(self, pid, source, inst))
	return total


## Resolve the top object of the stack (CR 608).
func _resolve_top() -> void:
	# THE PRE-FLIGHT (docs/duel-todo.md §1.3). Before anything happens, find
	# out what this item is going to ASK — by resolving it once over a
	# rewind point and throwing the run away. If it asks a human something
	# they have not answered, the item goes back on the stack and the
	# resolution is HELD OPEN until answer_choice() arrives.
	if stack.is_empty():
		# [member _held_answered] is scoped to ONE item's hold cycle. A
		# resolution that ends without resolving (the stack emptied under it)
		# must not leave its count standing: the next item's first probe
		# compares against it, and a stale count reads as "the answer that
		# was parked is not being served", which silently resolves that item
		# on the heuristic instead of holding it open.
		_held_answered = -1
		return
	var question := _preflight()
	if question != null:
		awaiting_choice = question
		_emit_state()
		return
	if undo_log != null:
		_rec(self, &"stack")
		_rec(self, &"_held_answered")
		_rec(self, &"_resolving_source")
		_rec(self, &"_resolving_controller")
		_rec(self, &"_resolving_item")
		_rec(self, &"_resolving_choices")
		_rec(self, &"choice_history")
	var item: StackItem = stack.pop_back()
	_rec_resolution(item)
	_held_answered = -1
	# THE QUESTION WINDOW: every mid-resolution question this item asks is
	# filed under the card that asked it, and any answer a UI parked for
	# THIS resolution is live for exactly its duration. See PlayerChoice and
	# HumanAgent.
	_resolving_source = item.card.data.card_name if item.card != null else ""
	_resolving_controller = item.controller
	_resolving_item = item
	_resolving_choices = []
	for agent in agents:
		agent.begin_resolution(_resolving_source)
	_run_item(item)
	for agent in agents:
		agent.end_resolution(_resolving_source)
	if _resolving_source != "" and not _resolving_choices.is_empty():
		choice_history[_resolving_source] = _resolving_choices
	_resolving_source = ""
	_resolving_controller = -1
	_resolving_item = null
	_resolving_choices = []
	check_state_based_actions()
	recalculate()
	if not game_over:
		_open_priority()


## Run one stack object's own resolution — the body of CR 608 with none of
## the bookkeeping around it. Split out of [method _resolve_top] because the
## pre-flight probe runs exactly this and nothing else.
func _run_item(item: StackItem) -> void:
	match item.kind:
		Mtg.StackKind.TRIGGER:
			# CR 608.2b — a targeted trigger whose target has become
			# illegal (left, gained shroud) fizzles: nothing happens.
			if _trigger_target_illegal(item):
				log_line("%s fizzles (illegal target)" % item.description)
			else:
				log_line("Resolving trigger: %s" % item.description)
				# The chosen target is readable as [method current_targets]
				# while the trigger resolves, exactly as an ability's is.
				var outer_targets := _resolving_targets
				var outer_mode := _resolving_mode
				var outer_delayed := _resolving_delayed
				_resolving_targets = item.targets
				_resolving_mode = item.mode
				_resolving_delayed = item.delayed
				item.trigger.on_resolve.call(self, item.card, item.event)
				_resolving_targets = outer_targets
				_resolving_delayed = outer_delayed
				_resolving_mode = outer_mode
		Mtg.StackKind.ABILITY:
			# CR 608.2b — an ability whose targets are ALL illegal is
			# countered: none of its effects happen, not even the
			# untargeted riders (Psionic Entity's self-damage).
			if _all_targets_illegal(item):
				log_line("%s is countered (no legal targets)" % item.description)
			else:
				log_line("Resolving: %s" % item.description)
				_run_effects(item)
		Mtg.StackKind.SPELL:
			_resolve_spell(item)


# ------------------------------------------------------------ the pre-flight --
#
# docs/duel-todo.md §1.3, and the answer to the question that item poses:
# "either the choice points become awaitable, or every one of them grows a
# pre-flight the UI can fill". They are not awaitable — a GDScript function
# that awaits returns a coroutine to its caller, and every one of these
# questions is asked from inside a Callable several frames deep in a card's
# effect, so making the ask awaitable would make the whole engine a
# coroutine and break every synchronous caller in it, tests included.
#
# So: the pre-flight. But it is not written out by hand 109 times — it is
# COMPUTED, by resolving the item once over a [GameSnapshot] and rewinding.
# The probe answers every question with the heuristic (so it always
# terminates and always follows a real branch), records what was asked, and
# is then undone: no log lines, no events, no state signals, no ledger, and
# the rng put back where it was. What survives is the QUESTION.
#
# The player answers it, the answer is parked on their agent, and the probe
# runs again — now serving the parked answer and finding whatever the card
# asks NEXT. That loop is what makes branching questions work ("don't pay"
# leads somewhere else than "pay") without any card knowing about it.

## The question the item on top of the stack will ask a seat that wants to
## be asked and has not answered yet — or null, in which case the item is
## ready to resolve for real.
func _preflight() -> PlayerChoice:
	if not interactive_choices or stack.is_empty() or _probing:
		return null
	var asks_anyone := false
	for agent in agents:
		if agent.wants_to_be_asked():
			asks_anyone = true
			break
	if not asks_anyone:
		return null
	var snapshot := GameSnapshot.take(self)
	# Pop it exactly as the real resolution will: an effect that reads the
	# stack must see what it would really see. The rewind puts it back.
	var item: StackItem = stack.pop_back()
	var outer_source := _resolving_source
	var outer_controller := _resolving_controller
	var outer_item := _resolving_item
	var outer_choices := _resolving_choices
	_probing = true
	_resolving_source = item.card.data.card_name if item.card != null else ""
	_resolving_controller = item.controller
	_resolving_item = item
	_resolving_choices = []
	_run_item(item)
	var asked: Array = _resolving_choices.duplicate()
	_probing = false
	snapshot.restore()
	_resolving_source = outer_source
	_resolving_controller = outer_controller
	_resolving_item = outer_item
	_resolving_choices = outer_choices
	var answered := 0
	var open_question: PlayerChoice = null
	for entry in asked:
		var choice: PlayerChoice = entry
		if choice.answered_by_player:
			answered += 1
			continue   # the player already parked this one
		if open_question != null:
			continue
		if choice.pid < 0 or choice.pid >= agents.size():
			continue
		# A seat is only held open on a question it can actually ANSWER
		# (DecisionAgent.can_answer). A kind its front end has no case for
		# would otherwise stop the duel dead; skipped, it falls through to
		# the heuristic and is ledgered like any other unanswered ask.
		if agents[choice.pid].wants_to_be_asked() \
				and agents[choice.pid].can_answer(choice):
			open_question = choice
	if open_question == null:
		return null
	# The LIVENESS CHECK. Every hold must consume the answer the last one
	# collected; if it did not, the answer is being parked under a name the
	# question does not match and asking again would loop forever. Resolve
	# on the heuristic instead — which is ledgered and logged, so the
	# player can see it happened.
	if answered <= _held_answered:
		return null
	_held_answered = answered
	return open_question


## Answer the question a resolution is being held open for
## (docs/duel-todo.md §1.3). [param value] is handed VERBATIM to the asked
## seat's [method DecisionAgent.accept_answer]; what it must be is that
## agent's business. HumanAgent, the only implementation, wants: a bool for
## a YES_NO, an Mtg.ManaColor bitmask for a COLOR, a card NAME for a CARD
## ("" declines, where declining is legal), and an Array of card names for a
## DISCARD — names rather than instances, because a shuffle between the
## question and the answer can replace the instances.
##
## The item then resolves, with this answer parked on the agent — and stops
## again for whatever the card asks next.
func answer_choice(value: Variant) -> String:
	if awaiting_choice == null:
		return "nothing is waiting on a choice"
	var choice := awaiting_choice
	awaiting_choice = null
	if choice.is_cost or not _pending_action.is_empty():
		# A COST question (CR 601.2h), or a TURN-BASED ACTION's (the untap
		# step — see [method _untap_step]). There is no stack item to
		# resolve and no rewind to undo — nothing was mutated when it was
		# asked — so the whole ACTION is simply re-issued, and each answer
		# is parked on the seat as the replay reaches the question it
		# belongs to (see [member _cost_values]). It may stop again on the
		# next question, which is why the answers are only cleared once
		# nothing is held.
		var action := _pending_action
		_pending_action = {}
		_cost_values.append(value)
		_cost_answers += 1
		_replaying_cost = true
		var err := _replay_cost_action(action)
		_replaying_cost = false
		if awaiting_choice == null:
			_cost_answers = 0
			_cost_values.clear()
		_emit_state()
		return err
	agents[choice.pid].accept_answer(choice, value)
	# The answer is parked; the item resolves from the top with it in hand.
	# (Nothing can have emptied the stack in the meantime — every action is
	# refused while a choice is open — but a caller that set the hold by hand
	# gets a parked answer and no crash rather than a popped null.)
	_resolve_top()
	_emit_state()
	return ""


## Withdraw the ACTION a cost question is holding open — the player clicked
## Ashnod's Altar, saw "Select creature to sacrifice", and thought better
## of it. Legal because of what the hold IS (see [member _pending_action]):
## a cost is paid only when the whole of it is known (CR 601.2h), and the
## hold is taken BEFORE anything is paid, so there is nothing to undo — the
## proposal is simply retracted (CR 728.1: a player may back out of an
## incomplete action). Only the player's OWN cost questions (a cast, an
## activation, a mana ability) can be withdrawn: a turn-based action's
## (`untap`, `begin_turn`), a trigger's target and an ADVERSE question put
## to the opponent must be answered, exactly as before.
func cancel_choice() -> String:
	if awaiting_choice == null:
		return "nothing is waiting on a choice"
	var kind := String(_pending_action.get("kind", ""))
	if awaiting_choice.adverse \
			or not (kind == "cast" or kind == "activate" or kind == "mana"):
		return "that question must be answered"
	awaiting_choice = null
	_pending_action = {}
	_cost_answers = 0
	_cost_values.clear()
	_emit_state()
	return ""


## True while a rewound PROBE resolution is running. Anything that keeps
## state the engine cannot rewind — an agent's mailbox, a UI's animation —
## must read this and hold still.
func is_probing() -> bool:
	return _probing


# --------------------------------------------------------- the COST hold --
#
# See the block beside [member _pending_action] for why these four sites —
# a mana ability's "Sacrifice a <X>" (CR 605.3a), Fellwar Stone's colour, a
# cast's additional sacrifice and an activation's (CR 601.2h) — cannot use
# the pre-flight, and why they do not need to.

## Start one action's cost-question count. Called at the top of every action
## that can ask one; a REPLAYED action (see [method answer_choice]) keeps the
## answers already given so it can serve them instead of re-asking.
func _begin_cost_choices() -> void:
	_cost_asked = 0
	if not _replaying_cost:
		_cost_answers = 0
		_cost_values.clear()
	_replaying_cost = false


## Build one COST question, wearing the card whose cost is being paid.
func _cost_question(pid: int, source: CardInstance, kind: int,
		prompt: String) -> PlayerChoice:
	var question := PlayerChoice.new(kind, pid, prompt)
	question.source = source.data.card_name
	question.step = current_step()
	question.is_cost = true
	return question


## HOLD the duel open on [param question] — true when it did, and the caller
## must then abandon the action with "" and change nothing: [param action] is
## the record [method answer_choice] re-issues once the answer is parked.
##
## False (carry on and ask the heuristic) when the pre-flight's own gates say
## so: interactive choices are off, a probe is running, the seat does not
## want to be asked, or its front end has no case for the kind
## ([method DecisionAgent.can_answer]) — and, crucially, when this question
## is one the player has ALREADY answered in an earlier run of the same
## action, whose answer is waiting in the mailbox.
func _hold_cost_choice(question: PlayerChoice, action: Dictionary) -> bool:
	_cost_asked += 1
	if _cost_asked <= _cost_answers:
		# The player's own answer to THIS question, parked now so the ask
		# that follows serves it (see [member _cost_values]).
		var pid_answered := question.pid
		if pid_answered >= 0 and pid_answered < agents.size():
			agents[pid_answered].accept_answer(question,
				_cost_values[_cost_asked - 1])
		return false
	if not interactive_choices or _probing or awaiting_choice != null:
		return false
	var pid := question.pid
	if pid < 0 or pid >= agents.size():
		return false
	if not agents[pid].wants_to_be_asked() or not agents[pid].can_answer(question):
		return false
	awaiting_choice = question
	_pending_action = action
	_emit_state()
	return true


## Ask [param pid] which body a cost eats. Scoped so the filed question wears
## [param source]'s name — that is what matches the answer the player parked
## to the card that asked for it. A cost's sacrifice is never optional
## (CR 601.2h), so a declined or stale answer falls back to the first body.
func _ask_cost_card(pid: int, source: CardInstance,
		candidates: Array[CardInstance], prompt: String) -> CardInstance:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked := agents[pid].choose_card(self, pid, candidates, prompt)
	_cost_source = outer
	if picked == null or not candidates.has(picked):
		picked = candidates[0]
	return picked


## Ask [param pid] whether — and which — body an OPTIONAL cost ask eats
## ("sacrifice any number of": each ask may be declined). Null = done.
func _ask_cost_card_optional(pid: int, source: CardInstance,
		candidates: Array[CardInstance], prompt: String) -> CardInstance:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked := agents[pid].choose_card(self, pid, candidates, prompt, true)
	_cost_source = outer
	if picked != null and not candidates.has(picked):
		picked = null
	return picked


## Ask [param pid] which cards a DISCARD cost eats, scoped to
## [param source] the way [method _ask_cost_card] is.
func _ask_cost_discard(pid: int, source: CardInstance,
		count: int) -> Array[CardInstance]:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked := agents[pid].choose_discard(self, pid, count)
	_cost_source = outer
	return picked


## Ask [param pid] which colour a mana ability makes (CR 605.1a — the choice
## is made as the ability is activated, and it never uses the stack).
## [param offered] is the Mtg.ManaColor flags on offer, and an answer outside
## it falls back to the first.
func _ask_cost_color(pid: int, source: CardInstance, offered: Array,
		prompt: String) -> int:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked: int = agents[pid].choose_color(self, pid, prompt, int(offered[0]))
	_cost_source = outer
	return picked if offered.has(picked) else int(offered[0])


## Ask [param pid] one OPTION question that is part of a COST — how many
## charge counters a mana battery spends (CR 601.2b: a variable in a cost
## is announced with the activation). Returns the chosen INDEX, which for a
## "0".."N" list is the number itself; scoped to [param source] the way
## [method _ask_cost_card] is.
func _ask_cost_option(pid: int, source: CardInstance, options: Array[String],
		prompt: String, hint: int) -> int:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked: int = agents[pid].choose_option(self, pid, options, prompt, hint)
	_cost_source = outer
	return clampi(picked, 0, options.size() - 1)


# ------------------------------------------- targets an OPPONENT chooses --
#
# "… of an opponent's choice" (Arena, Preacher, Nova Pentacle, Cuombajj
# Witches): a real target (CR 115.1) that the ACTIVATOR does not name. It is
# chosen when the ability is put on the stack, with the activator's own
# targets (CR 601.2c), by asking that opponent — and the ask rides the COST
# hold above: it comes after every refusal, before anything is mutated, and
# a human opponent is held on it exactly as a human payer is held on a
# sacrifice pick, the activation re-issued once their answer is parked.

## The refusal an opponent-chosen spec makes BEFORE anyone is asked: with
## no legal candidate the ability can't be activated at all (CR 601.2c —
## a target must be chosen for every instance of "target").
func _adverse_targets_refusal(plan: TargetPlan, source: CardInstance) -> String:
	for gi in plan.adverse_groups:
		var spec: TargetSpec = plan.specs[gi]
		if spec.legal_targets(self, source, _earlier_refs(plan, gi)).is_empty():
			return "no legal target for '%s'" % spec.description
	return ""


## The refs [param plan] holds for the groups BEFORE [param gi] — what a
## [member TargetSpec.sibling_filter] on group [param gi] reads.
func _earlier_refs(plan: TargetPlan, gi: int) -> Array:
	var out: Array = []
	for k in mini(gi, plan.groups.size()):
		out.append_array(plan.groups[k])
	return out


## Fill every opponent-chosen group of [param plan] by asking the
## opponent of [param pid]. False when a question HELD the action open
## ([method _hold_cost_choice]) — the caller then returns "" and the
## re-issued action reaches here again with the answer parked.
##
## A list of cards is one CARD question; "any target" (Cuombajj Witches)
## can name a player too, so that list is an OPTION question whose labels
## are the candidates' names, answered by index. Either way the candidates
## come ordered by the spec's [member TargetSpec.chooser_order], so the
## first is what the chooser's heuristic takes ([member PlayerChoice.adverse]).
func _fill_adverse_targets(plan: TargetPlan, pid: int, source: CardInstance,
		action: Dictionary) -> bool:
	for gi in plan.adverse_groups:
		var spec: TargetSpec = plan.specs[gi]
		var chooser := opponent_of(pid)
		var refs: Array[TargetRef] = spec.legal_targets(self, source,
			_earlier_refs(plan, gi))
		if refs.is_empty():
			continue   # refused before we got here; nothing to fill
		if spec.chooser_order.is_valid():
			# The order may weigh the ACTIVATOR's own picks (Arena's
			# champion is chosen against a known foe), so they are readable
			# as [method current_targets] while it sorts.
			var order: Callable = spec.chooser_order
			var outer_targets := _resolving_targets
			_resolving_targets = plan.flat()
			refs.sort_custom(func(a: TargetRef, b: TargetRef) -> bool:
				return bool(order.call(self, source, a, b)))
			_resolving_targets = outer_targets
		var prompt: String = spec.chooser_prompt
		if prompt == "":
			prompt = "Select %s." % spec.description
		var cards: Array[CardInstance] = []
		for ref in refs:
			if ref.is_player or ref.is_damage or ref.is_ability:
				cards.clear()
				break
			cards.append(find_instance(ref.instance_id))
		if not cards.is_empty():
			var card_q := _cost_question(chooser, source, PlayerChoice.Kind.CARD,
				prompt)
			card_q.candidates = cards
			card_q.adverse = true
			card_q.hint = cards[0]
			if _hold_cost_choice(card_q, action):
				return false
			var picked := _ask_adverse_card(chooser, source, cards, prompt)
			plan.groups[gi] = [TargetRef.card(picked)]
			continue
		var labels: Array[String] = []
		for ref in refs:
			labels.append(target_label(ref))
		var option_q := _cost_question(chooser, source, PlayerChoice.Kind.OPTION,
			prompt)
		option_q.options = labels
		option_q.adverse = true
		option_q.hint = 0
		if _hold_cost_choice(option_q, action):
			return false
		var index := _ask_adverse_option(chooser, source, labels, prompt)
		plan.groups[gi] = [refs[index]]
	return true


# ------------------------------------------------- targets the GAME rolls --
#
# "… random target creature(s)" (Faerie Dragon, Goblin Polka Band, Orcish
# Catapult): a real target (CR 115.1) that NOBODY names. The roll is made
# when the spell or ability is put on the stack, with the caster's own
# targets (CR 601.2c), on [member rng] so a seeded duel replays it — and
# it comes after every refusal and every cost question, so a cast that is
# refused or held never consumes a roll, and a held one rolls exactly once.

## The refusal a rolled spec makes BEFORE anything is rolled: with no legal
## candidate and at least one target required, the spell can't be cast at
## all (CR 601.2c — a target must be chosen for every instance of
## "target"). A divided effect with nothing to divide (Orcish Catapult for
## X=0) requires none, and "any number" (the Polka Band for X=0) never did.
func _random_targets_refusal(plan: TargetPlan, source: CardInstance) -> String:
	for k in plan.random_groups.size():
		var gi: int = plan.random_groups[k]
		var need: int = plan.random_spans[k].x
		if plan.random_totals[k] == 0:
			need = 0
		if need <= 0:
			continue
		var spec: TargetSpec = plan.specs[gi]
		if spec.legal_targets(self, source, _earlier_refs(plan, gi)).is_empty():
			return "no legal target for '%s'" % spec.description
	return ""


## Fill every rolled group of [param plan]: HOW MANY (the effect's range,
## bounded by what exists and by a divided total — and rolled within it
## for a [member TargetSpec.random_count] spec, else as many as allowed),
## then WHICH ([method RandomEffects.sample] — distinct, CR 601.2c), then
## for a divided effect the SHARES (every target at least one, the rest
## dropped one by one into random hands — CR 601.2d, locked in now: a
## target that leaves takes its share with it, nothing is redistributed).
## Logged, so the roll is on the record the moment it is made.
func _fill_random_targets(plan: TargetPlan, source: CardInstance) -> void:
	for k in plan.random_groups.size():
		var gi: int = plan.random_groups[k]
		var spec: TargetSpec = plan.specs[gi]
		var span: Vector2i = plan.random_spans[k]
		var total: int = plan.random_totals[k]
		var refs: Array[TargetRef] = spec.legal_targets(self, source,
			_earlier_refs(plan, gi))
		var hi: int = span.y
		if hi < 0 or hi > refs.size():
			hi = refs.size()
		if total >= 0:
			hi = mini(hi, total)
		var lo: int = mini(span.x, hi)
		var count: int = hi
		if spec.random_count and hi > lo:
			count = lo + RandomEffects.roll(self, hi - lo + 1)
		var chosen: Array = RandomEffects.sample(self, refs, count)
		var group: Array = []
		if total > 0 and not chosen.is_empty():
			var shares: Array = RandomEffects.distribute(self,
				total - chosen.size(), chosen.size())
			for i in chosen.size():
				var extra: int = int(shares[i]) if i < shares.size() else 0
				group.append(chosen[i].with_amount(1 + extra))
		else:
			group = chosen
		plan.groups[gi] = group
		var names: Array[String] = []
		for ref in group:
			var label := target_label(ref)
			if total > 0:
				label += " (%d)" % ref.amount
			names.append(label)
		log_line("%s's random target%s: %s" % [source.data.card_name,
			"" if group.size() == 1 else "s",
			", ".join(names) if not names.is_empty() else "none"])


## Ask [param pid] — the OPPONENT of the activator — which of
## [param candidates] their choice names, scoped to [param source] the way
## [method _ask_cost_card] is. Never optional: a stale or declined answer
## is the first candidate, the one the order put there.
func _ask_adverse_card(pid: int, source: CardInstance,
		candidates: Array[CardInstance], prompt: String) -> CardInstance:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked := agents[pid].choose_card(self, pid, candidates, prompt,
		false, true)
	_cost_source = outer
	if picked == null or not candidates.has(picked):
		picked = candidates[0]
	return picked


## As [method _ask_adverse_card], for a list that includes players:
## returns the index into [param labels].
func _ask_adverse_option(pid: int, source: CardInstance,
		labels: Array[String], prompt: String) -> int:
	var outer := _cost_source
	_cost_source = source.data.card_name
	var picked: int = agents[pid].choose_option(self, pid, labels, prompt,
		0, true)
	_cost_source = outer
	return clampi(picked, 0, labels.size() - 1)


## The name a target wears in a list: the card's, or the player's.
func target_label(ref: TargetRef) -> String:
	if ref.is_player:
		return players[ref.player_id].player_name
	if ref.is_damage:
		return "damage #%d" % ref.packet_id
	if ref.is_ability:
		return "ability #%d" % ref.ability_id
	var inst := find_instance(ref.instance_id)
	return inst.data.card_name if inst != null else str(ref)


## Re-issue the action a cost question was held open on. Nothing had been
## mutated when the question was put and no refusal was left, so this is a
## plain second call with the answer now in the seat's mailbox.
func _replay_cost_action(action: Dictionary) -> String:
	match String(action.get("kind", "")):
		"cast":
			return cast_spell(int(action["pid"]), action["inst"],
				action["targets"], int(action["x"]), int(action["mode"]))
		"activate":
			return activate_ability(int(action["pid"]), action["inst"],
				int(action["index"]), action["targets"], int(action["x"]))
		"mana":
			return tap_for_mana(int(action["pid"]), action["inst"],
				int(action["index"]))
		"blockers":
			# Camouflage's pile questions (see [method _camouflage_block_map]):
			# the declaration is re-issued with the answers in hand — the
			# map itself is discarded under Camouflage, so an empty one
			# is all the replay needs.
			return declare_blockers(int(action["pid"]), {})
		"untap":
			# The untap step's own hold (CR 502.3): re-run its decisions
			# with the answers in hand, and move on once none is left.
			if _untap_step():
				_advance_step()
			return ""
		"begin_turn":
			# The turn's own hold ("if you would begin your turn" — Time
			# Vault): re-run the asking with the answer in hand. "Play"
			# goes on into the untap step, which may hold on a question
			# of its own; "skip" has already entered the next turn.
			if _begin_turn() and _untap_step():
				_advance_step()
			return ""
		"trigger_target":
			# A targeted trigger's question (CR 603.3d), put as a player
			# was about to receive priority: give it again, which re-runs
			# the pass with the answer in hand and may stop on the next
			# held trigger's question. `pid` names the player who was
			# keeping priority after their own action (CR 117.3c); absent,
			# priority was being opened afresh.
			var actor := int(action.get("pid", -1))
			if actor >= 0:
				_resume_priority(actor)
			else:
				_open_priority()
			return ""
	return ""


# ------------------------------------------------ the TURN-BASED hold --
#
# A question asked by a turn-based action (CR 500.1: the untap step's
# "which creature untaps under Smoke", "does the Old Man stay tapped") has
# no stack item for the pre-flight to probe and no cost to replay — but the
# COST hold's record-and-replay fits it exactly: the action collects every
# decision BEFORE it mutates anything, so it can be re-issued from the top
# with the answers parked, and it stops again on the next question. These
# helpers are the cost hold's, scoped by [member _turn_source] instead of
# [member _cost_source] so the question is not stamped as a cost.

## Build one turn-based question, wearing [param source_name].
func _turn_question(pid: int, source_name: String, kind: int,
		prompt: String) -> PlayerChoice:
	var question := PlayerChoice.new(kind, pid, prompt)
	question.source = source_name
	question.step = current_step()
	return question


## Ask [param pid] to pick one of [param candidates] for a turn-based
## action, scoped to [param source_name]. Never optional: a declined or
## stale answer falls back to the first candidate.
func _ask_turn_card(pid: int, source_name: String,
		candidates: Array[CardInstance], prompt: String) -> CardInstance:
	var outer := _turn_source
	_turn_source = source_name
	var picked := agents[pid].choose_card(self, pid, candidates, prompt)
	_turn_source = outer
	if picked == null or not candidates.has(picked):
		picked = candidates[0]
	return picked


## Ask [param pid] one of [param options] for a turn-based action, scoped
## to [param source_name]; returns the index.
func _ask_turn_option(pid: int, source_name: String, options: Array[String],
		prompt: String, hint: int) -> int:
	var outer := _turn_source
	_turn_source = source_name
	var picked := agents[pid].choose_option(self, pid, options, prompt, hint)
	_turn_source = outer
	return picked


## Does [param item] target, with every one of its chosen targets now
## illegal? (CR 608.2b — the fizzle test, shared by spells and abilities.)
func _all_targets_illegal(item: StackItem) -> bool:
	var targeting := false
	var group_i := 0
	var earlier: Array = []   # the slots before this one, for sibling specs
	for effect in item.effects:
		if effect.target_spec == null:
			continue
		var group: Array = []
		if group_i < item.target_groups.size():
			group = item.target_groups[group_i]
		elif group_i < item.targets.size():
			group = [item.targets[group_i]]
		group_i += 1
		# A slot with NO target in it does not make this a targeted
		# ability at all (CR 115.5, 601.2c), so it cannot fizzle for
		# having no legal one — a Circle of Protection with no damage
		# window open still puts up its shield (§6.8), and a Polka Band
		# activated for X=0 resolves doing nothing rather than fizzling.
		if group.is_empty():
			continue
		targeting = true
		for ref in group:
			if effect.target_spec.is_legal(self, ref, item.card, earlier):
				return false
		earlier.append_array(group)
	return targeting


func _resolve_spell(item: StackItem) -> void:
	var inst := item.card
	# Fizzle check: a spell with targets, all of which are now illegal, is
	# countered on resolution (CR 608.2b).
	var specs := _spell_target_specs(inst.data, item.mode)
	if not specs.is_empty():
		var any_legal := false
		var targeting := false   # a slot with no ref in it targets nothing (CR 115.5)
		var earlier: Array = []   # the slots before this one, for sibling specs
		for i in specs.size():
			var group: Array = []
			if i < item.target_groups.size():
				group = item.target_groups[i]
			elif i < item.targets.size():
				group = [item.targets[i]]
			if not group.is_empty():
				targeting = true
			for ref in group:
				if specs[i].is_legal(self, ref, inst, earlier):
					any_legal = true
			earlier.append_array(group)
		if targeting and not any_legal:
			log_line("%s fizzles (no legal targets) " % inst.data.card_name)
			_spell_to_graveyard(inst)
			return
	if inst.data.is_permanent_type():
		log_line("Resolving: %s enters the battlefield" % inst.data.card_name)
		if inst.data.is_aura():
			var host := find_instance(item.targets[0].instance_id)
			# Animate Dead: raise the graveyard target FIRST, then attach.
			if inst.data.aura_reanimates and host.zone == Mtg.Zone.GRAVEYARD:
				reanimate(host, item.controller)
			# It enters ATTACHED (CR 303.4a) — the host rides along.
			if not _put_on_battlefield(inst, item.controller, host):
				return   # refused entry: it is already in its owner's graveyard
			# Control Magic: attaching takes the host.
			if inst.data.aura_steals:
				change_control(host, item.controller)
			recalculate()
		else:
			_put_on_battlefield(inst, item.controller)
	else:
		log_line("Resolving: %s" % inst.data.card_name)
		_run_effects(item)
		_spell_to_graveyard(inst)


## Where a finished instant/sorcery goes. A card goes to its owner's
## graveyard; a COPY of a spell (Fork) is not a card and simply ceases to
## exist (CR 707.10a / 608.2m).
func _spell_to_graveyard(inst: CardInstance) -> void:
	_forget_x(inst)
	# "Exile Recall" — a spell that removes itself on resolution.
	if inst.exile_after_resolution and not inst.is_copy:
		_rec_move(inst, inst.owner_id, Mtg.Zone.EXILE)
		_rec(inst, &"exile_after_resolution")
		inst.exile_after_resolution = false
		inst.zone = Mtg.Zone.EXILE
		players[inst.owner_id].exile.append(inst)
		log_line("%s is exiled" % inst.data.card_name)
		return
	if inst.is_copy:
		if undo_log != null:
			_rec(inst, &"zone")
			_rec(self, &"_instances")
		inst.zone = Mtg.Zone.EXILE   # nowhere, really — it stops existing
		_instances.erase(inst.id)
		return
	_rec_move(inst, inst.owner_id, Mtg.Zone.GRAVEYARD)
	inst.zone = Mtg.Zone.GRAVEYARD
	players[inst.owner_id].graveyard.append(inst)


## Run a stack item's effects in order, pairing each targeting effect with
## its chosen target. Individually illegal targets skip just that effect
## (CR 608.2c — the rest of the spell still happens).
func _run_effects(item: StackItem) -> void:
	# The whole object's target list, for the effect that needs a SIBLING
	# slot (see [method current_targets]). Restored rather than cleared so a
	# resolution nested inside another one (a copy resolving mid-resolution)
	# hands the outer one its list back.
	var outer_targets := _resolving_targets
	var outer_cost := _resolving_cost
	_resolving_targets = item.targets
	_resolving_cost = item.cost_paid
	_run_effects_impl(item)
	_resolving_targets = outer_targets
	_resolving_cost = outer_cost


func _run_effects_impl(item: StackItem) -> void:
	var group_i := 0
	var earlier: Array = []   # the slots before this one, for sibling specs
	for effect in item.effects:
		var group: Array = []
		if effect.target_spec != null:
			# Each targeting effect owns one GROUP of refs (one for the
			# single-target majority, N for "X target creatures" and the
			# divided spells) — see TargetPlan.
			if group_i < item.target_groups.size():
				group = item.target_groups[group_i]
			elif group_i < item.targets.size():
				group = [item.targets[group_i]]   # triggers/legacy callers
			group_i += 1
			# Targets that became illegal drop out individually; the rest of
			# the effect still happens (CR 608.2c). A slot stated relative
			# to an earlier one (TargetSpec.sibling_filter) is judged with
			# the refs that slot holds, illegal or not — the requirement is
			# about the object that was named.
			var still_legal: Array = []
			for ref in group:
				if effect.target_spec.is_legal(self, ref, item.card, earlier):
					still_legal.append(ref)
			earlier.append_array(group)
			if still_legal.size() < group.size():
				log_line("(target for '%s' is illegal — skipped)" % effect.target_spec.description)
			if still_legal.is_empty():
				# ...unless the target was OPTIONAL and none was taken, in
				# which case the effect has its own untargeted behaviour
				# (§6.8: a Circle of Protection outside a damage window).
				if not (effect.resolves_untargeted and group.is_empty()):
					continue
			group = still_legal
		effect.resolve_multi(self, item.card, item.controller, group, item.x_value)


## [param host]: the object an AURA enters attached to. An Aura enters the
## battlefield ALREADY attached (CR 303.4a-b: "an Aura spell that resolves
## enters attached to the object it targeted"), so the attachment is made
## here, before the first recalculation, before "as this enters" and
## before the ENTERS_BATTLEFIELD event — an Aura's own arrival trigger
## (Earthbind's "if enchanted creature has flying") and its static
## abilities see their host from the very first moment.
func _put_on_battlefield(inst: CardInstance, controller: int,
		host: CardInstance = null) -> bool:
	# "Lands can't enter the battlefield" (Worms of the Earth) and "put this
	# creature into its owner's graveyard instead of onto the battlefield"
	# (Frankenstein's Monster): a refusal, asked before anything about the
	# arrival has happened. Returns false to every caller that has post-work
	# to skip; the object itself is put back where it came from.
	var refused := entry_refused(inst, controller)
	if refused != "":
		_arrival_refused(inst, refused)
		return false
	if undo_log != null:
		_rec(inst, &"zone")
		_rec(inst, &"controller_id")
		_rec(inst, &"summoning_sick")
		_rec(inst, &"tapped")
		_rec(inst, &"counters")
		_rec(players[controller], &"battlefield")
		_rec(players[controller], &"acted_this_turn")
		_rec(self, &"_battlefield_order")
	inst.zone = Mtg.Zone.BATTLEFIELD
	inst.controller_id = controller
	if host != null:
		if undo_log != null:
			_rec(inst, &"attached_to")
			_rec(host, &"attachments")
		inst.attached_to = host.id
		host.attachments.append(inst.id)
	# Arboria: "put a nontoken permanent onto the battlefield during their
	# last turn" — again, only on that player's own turn.
	if not inst.is_token and controller == active_player:
		players[controller].acted_this_turn = true
	# CR 400.7 + 506.4: what arrives is a NEW object and was never declared
	# as an attacker or a blocker. A card that left the battlefield mid-combat
	# and comes straight back keeps its instance id (Tawnos's Coffin releasing
	# its prisoner when the Coffin is untapped), so a stale combat entry under
	# that id would let it deal its combat damage a second time.
	combat.forget(inst.id)
	# "You may have this enter as a copy of ..." is a REPLACEMENT effect
	# (CR 614.1c): it applies as the permanent enters, before anything —
	# including state-based actions — ever sees the printed 0/0 body.
	if not inst.data.enters_as_copy.is_empty():
		_apply_enters_as_copy(inst, controller)
	# EVERY permanent starts "sick" — the flag really means "not under its
	# controller's control since their turn began" (CR 302.6), and a LAND
	# animated into a creature the turn it was played must not attack.
	inst.summoning_sick = true
	inst.tapped = _arrives_tapped(inst, controller)
	for kind in inst.data.enters_with_counters:   # Triskelion, Clockwork Beast
		inst.counters[kind] = int(inst.data.enters_with_counters[kind])
	players[controller].battlefield.append(inst)
	_battlefield_order.append(inst.id)
	_battlefield_changed()
	recalculate()
	# "As this permanent enters, ..." — a REPLACEMENT effect (CR 614.1c).
	# It runs with the permanent already on the battlefield, so it may
	# sacrifice, pay life or ask its controller something, but before state
	# -based actions and before the ENTERS_BATTLEFIELD trigger below: a */*
	# body (Wood Elemental, Nameless Race) has to settle its size before
	# anything could see a 0/0. The second recalculate is what publishes
	# whatever the callback wrote into memory.
	if inst.data.as_enters.is_valid():
		inst.data.as_enters.call(self, inst, controller)
		recalculate()
	dispatch_event(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": inst, "controller": controller})
	return true


## Why [param inst] may NOT enter the battlefield under [param controller],
## or "" when it may. Two sources, and both are CR 614.1c-shaped
## prohibitions rather than modifications:
## - the card's OWN veto ([member CardData.entry_condition]) — "if you
##   can't, put this creature into its owner's graveyard instead of onto
##   the battlefield" (Frankenstein's Monster);
## - a ban RADIATED by something already on the battlefield
##   ([member CardData.enters_ban_rule]) — "lands can't enter the
##   battlefield" (Worms of the Earth).
##
## Asked before the permanent touches the battlefield, which is what makes
## the printed wording true: a refused arrival fires no
## enters-the-battlefield trigger and, because the object never entered, no
## leave- or dies-trigger either.
func entry_refused(inst: CardInstance, controller: int) -> String:
	if inst == null:
		return ""
	if inst.data.entry_condition.is_valid():
		var own_veto := String(
			inst.data.entry_condition.call(self, inst, controller))
		if own_veto != "":
			return own_veto
	for other in all_battlefield():
		if other == inst or other.cur_abilities_silenced \
				or other.cur_statics_suspended:
			continue
		if not other.data.enters_ban_rule.is_valid():
			continue
		if bool(other.data.enters_ban_rule.call(self, other, inst, controller)):
			return other.data.card_name
	return ""


## An arrival was refused ([method entry_refused]). The object never enters
## the battlefield, so it stays in the zone it was about to leave: a
## fetched land goes back into the library (which its search shuffles
## anyway), a card offered from a hand, a graveyard or exile stays there.
## A permanent SPELL has no zone to stay in — the stack is not a resting
## place — so it is put into its owner's graveyard, and a TOKEN that cannot
## enter simply ceases to exist (CR 111.7).
func _arrival_refused(inst: CardInstance, why: String) -> void:
	log_line("%s can't enter the battlefield (%s)" % [inst.data.card_name, why])
	if inst.is_token:
		if undo_log != null:
			_rec(inst, &"zone")
			_rec(self, &"_instances")
		inst.zone = Mtg.Zone.EXILE   # nowhere, really — it stops existing
		_instances.erase(inst.id)
		return
	var home := players[inst.owner_id]
	if undo_log != null:
		_rec(inst, &"zone")
		for f in ZONE_FIELD.values():
			_rec(home, f)
	match inst.zone:
		Mtg.Zone.LIBRARY:
			if not home.library.has(inst):
				home.library.append(inst)
				_shuffle(home.library)
		Mtg.Zone.HAND:
			if not home.hand.has(inst):
				home.hand.append(inst)
		Mtg.Zone.EXILE:
			if not home.exile.has(inst):
				home.exile.append(inst)
		Mtg.Zone.GRAVEYARD:
			if not home.graveyard.has(inst):
				home.graveyard.append(inst)
		_:
			inst.zone = Mtg.Zone.GRAVEYARD
			if not home.graveyard.has(inst):
				home.graveyard.append(inst)
	_emit_state()


## Does [param inst] arrive TAPPED? Its own printed clause (Nevinyrral's
## Disk), or a replacement radiated by something already on the battlefield
## (Kismet) — CR 614.1c, so the permanent is never untapped for an instant
## and no became-tapped trigger fires. [param inst] is not on the
## battlefield yet, which is exactly why this is asked here and not by a
## trigger.
func _arrives_tapped(inst: CardInstance, controller: int) -> bool:
	if inst.data.enters_tapped:
		return true
	for other in all_battlefield():
		if other.cur_abilities_silenced or other.cur_statics_suspended:
			continue
		if not other.data.enters_tapped_rule.is_valid():
			continue
		if bool(other.data.enters_tapped_rule.call(self, other, inst, controller)):
			log_line("%s enters tapped (%s)" % [
				inst.data.card_name, other.data.card_name])
			return true
	return false


## Resolve a card's enters-as-a-copy replacement (Clone, Copy Artifact,
## Vesuvan Doppelganger). The controller's agent picks what to copy; with
## nothing legal to copy the permanent simply enters as printed.
func _apply_enters_as_copy(inst: CardInstance, controller: int) -> void:
	var spec: Dictionary = inst.data.enters_as_copy
	var filter: Callable = spec["filter"]
	var candidates: Array[CardInstance] = []
	for other in all_battlefield():
		if other != inst and (not filter.is_valid() or filter.call(other)):
			candidates.append(other)
	if candidates.is_empty():
		return
	# "YOU MAY have this enter as a copy of ..." — declining is legal and
	# is sometimes the only sane line (a forced copy of an opponent's Lord
	# of the Pit or Ankh of Mishra is worse than entering as a 0/0), so the
	# question is OPTIONAL: a null answer means "enter as printed".
	var chosen := agents[controller].choose_card(self, controller, candidates,
		"Copy %s?" % String(spec.get("desc", "a permanent")), true)
	if chosen == null:
		return
	if not candidates.has(chosen):
		chosen = candidates[0]
	var adopted: CardData = chosen.data
	var transform: Callable = spec.get("transform", Callable())
	if transform.is_valid():
		adopted = transform.call(chosen.data)
	become_copy(inst, adopted, int(spec.get("extra_types", 0)),
		bool(spec.get("keep_own_colors", false)))


## Run a departing permanent's IMMEDIATE leave hook
## ([member CardData.as_leaves]). Every one of the battlefield's four exits
## — graveyard, exile, hand and ante — calls this at exactly the same
## point: after the leave-triggers are on the stack (CR 603.6d) and after
## this object's own floating effects are forgotten (CR 400.7), and before
## [method recalculate] recomputes the world without it.
##
## That instant is the whole reason the hook exists. A trigger resolves
## from the stack, by which time the departing permanent's statics have
## already been un-applied, so "this effect continues until end of turn"
## (Titania's Song) has nothing left to continue. Here the board is still
## exactly as the permanent left it, and the callback can register floating
## effects with a duration of their own ([ContinuousEffects.Duration]).
##
## [param parting_memory] is the same snapshot of
## [member CardInstance.memory] the LEAVES_BATTLEFIELD event carries. The
## live one is already gone — [method CardInstance.clear_battlefield_state]
## wipes card-local choices as the permanent leaves — so a hook that has to
## remember something (Oubliette's prisoner) reads it from here.
func _run_leave_hook(inst: CardInstance, was_controller: int,
		parting_memory: Dictionary) -> void:
	# Seat-level permissions keyed to the departed object go with it, for
	# the reason [method ContinuousEffects.forget_instance] just ran: what
	# comes back is a NEW object (CR 400.7), not "that permanent".
	_drop_paid_prevention_for(inst.id)
	if inst.data.as_leaves.is_valid():
		inst.data.as_leaves.call(self, inst, was_controller, parting_memory)


## [param sacrificed]: the permanent was SACRIFICED rather than destroyed
## or put there by a rule. It rides on the LEAVES_BATTLEFIELD and DIES
## events as `sacrificed`, because "if it wasn't sacrificed" is a clause
## real cards carry (Urza's Miter) and nothing else can tell the two apart
## once the permanent is in the graveyard.
func _move_to_graveyard(inst: CardInstance, died: bool,
		sacrificed := false) -> void:
	# "If this creature would die, return it to its owner's hand instead"
	# (Firestorm Phoenix) — a replacement effect, so no dies-trigger fires.
	if died and inst.data.dies_returns_to_hand and not inst.is_token:
		log_line("%s returns to its owner's hand instead of dying" % inst.data.card_name)
		return_to_hand(inst)
		if inst.data.dies_to_hand_locks and inst.zone == Mtg.Zone.HAND:
			_lock_in_hand(inst)
		return
	# "If it would die this turn, exile it instead" (Disintegrate) — a
	# replacement, so no dies-trigger fires and nothing hits a graveyard.
	if died and inst.exile_instead_of_dying and not inst.is_token:
		log_line("%s is exiled instead of dying" % inst.data.card_name)
		exile_permanent(inst)
		return
	var controller := inst.controller_id
	_rec_departure(inst, inst.owner_id, Mtg.Zone.GRAVEYARD)
	# Snapshot per-turn bookkeeping BEFORE the battlefield-state wipe —
	# dies-triggers (Sengir Vampire) read it from the event.
	var damaged_by := inst.damaged_by_this_turn.duplicate()
	var damaged_by_amounts := inst.damage_from_this_turn.duplicate()
	# Card-local choices die with the battlefield state, so leave- and
	# dies-triggers get a SNAPSHOT of them (Dance of Many remembers which
	# token it made; Jihad remembers its colour).
	var parting_memory := inst.memory.duplicate()
	# Departing control/reanimation auras settle their host's fate first:
	# stolen hosts go home (Control Magic), reanimated ones die again
	# (Animate Dead) — checked before attachment state wipes.
	_detach_departing_aura(inst)
	players[controller].battlefield.erase(inst)
	_battlefield_order.erase(inst.id)
	_battlefield_changed()
	# Anything attached to it is now orphaned; SBA sweeps it to the graveyard.
	inst.clear_battlefield_state()
	inst.zone = Mtg.Zone.GRAVEYARD
	# A TOKEN ceases to exist instead of resting in a graveyard
	# (CR 704.5e) — its dies-trigger still fires, then it is gone.
	if not inst.is_token:
		players[inst.owner_id].graveyard.append(inst)
	dispatch_event(Mtg.EventType.LEAVES_BATTLEFIELD,
		{"instance": inst, "from_controller": controller,
			"sacrificed": sacrificed, "memory": parting_memory},
		inst)   # the departing card hears its own leave-trigger (CR 603.6d)
	if died:
		# LAST KNOWN INFORMATION (CR 608.2h): an animated Mishra's Factory
		# died as a creature even though its printed types say otherwise.
		if (inst.last_types & Mtg.CardType.CREATURE) != 0:
			creatures_died_this_turn += 1
		dispatch_event(Mtg.EventType.DIES,
			{"instance": inst, "controller": controller,
				"damaged_by": damaged_by,
				"damaged_by_amounts": damaged_by_amounts,
				"sacrificed": sacrificed, "memory": parting_memory},
			inst)   # the dead card hears its own dies-trigger (603.6b)
		# Floating "when that creature dies this turn" watches
		# (Reincarnation) — they outlive whatever placed them, and each
		# fires once.
		for i in range(death_watchers.size() - 1, -1, -1):
			if int(death_watchers[i]["instance_id"]) != inst.id:
				continue
			var watch: Dictionary = death_watchers[i]
			death_watchers.remove_at(i)
			watch["callback"].call(self, inst)
	if inst.is_token:
		inst.zone = Mtg.Zone.EXILE   # gone for good; nothing can find it
		_instances.erase(inst.id)
	# The object that left is a NEW object wherever it landed (CR 400.7):
	# drop every until-end-of-turn effect still keyed to its id, or replaying
	# the card this turn would inherit them.
	continuous.forget_instance(inst.id)
	_run_leave_hook(inst, controller, parting_memory)
	# A copy is only a copy while it is on the battlefield (CR 707.2). The
	# identity is restored HERE, after its own leave- and dies-triggers have
	# been offered the event, so a Clone of Onulet still pays out (608.2h).
	inst.restore_printed_identity()
	recalculate()


## Create [param count] TOKENS from [param data] under [param controller]'s
## control (Rukh Egg's bird, The Hive's wasps, Boris Devilboon's demons).
## Tokens are ordinary CardInstances with is_token set: they get ETB
## triggers, summoning sickness and everything else, but cease to exist
## when they leave the battlefield (CR 704.5e).
## Returns the tokens created.
func create_token(controller: int, data: CardData, count := 1) -> Array[CardInstance]:
	var made: Array[CardInstance] = []
	for _i in count:
		var inst := CardInstance.new(data, _next_instance_id, controller)
		_rec(self, &"_next_instance_id")
		_rec(self, &"_instances")
		_next_instance_id += 1
		inst.is_token = true
		_instances[inst.id] = inst
		if not _put_on_battlefield(inst, controller):
			continue   # refused entry: it never existed (CR 111.7)
		made.append(inst)
		log_line("%s creates %s" % [players[controller].player_name, data.card_name])
	return made


## Queue a TOKEN to be created at the beginning of the next end step
## (Rukh Egg's 4/4 bird). Survives its source leaving the battlefield —
## the delayed effect is independent of the card that scheduled it.
func schedule_end_step_token(controller: int, data: CardData) -> void:
	_end_step_tokens.append({"controller": controller, "data": data})


## Create a DELAYED triggered ability (CR 603.7a) — see [member
## delayed_triggers]. [param trig] is an ordinary [TriggeredAbility]
## whose condition and resolution are handed [param source] as usual;
## "you" in its text is [param controller], the player who controlled
## the spell or ability that created it (CR 603.7d), fixed here — a
## card that binds the controller into its callables reads the same
## value. It triggers ONCE (CR 603.7c) unless [param repeats], and
## [param memory] is state the trigger may keep between firings, read
## and written on resolution through [method current_delayed] (it is
## journaled with the queue, which a Callable's bound arguments are
## not). Returns the entry, so the caller may add a settlement (Nafs
## Asp: [method settle_delayed_trigger]).
func schedule_delayed_trigger(trig: TriggeredAbility, controller: int,
		source: CardInstance, repeats := false, memory := {},
		desc := "") -> Dictionary:
	_rec(self, &"delayed_triggers")
	_rec(self, &"_next_delayed_id")
	var entry := {
		"id": _next_delayed_id, "trigger": trig, "controller": controller,
		"source": source, "repeats": repeats, "memory": memory,
		"desc": desc if desc != "" else trig.text,
	}
	_next_delayed_id += 1
	delayed_triggers.append(entry)
	return entry


## "... unless they pay {1} before that draw step" (Nafs Asp): the entry
## may be SETTLED — paid off and dropped — by [param pid] before it
## triggers, any time they have priority. The card sets `settle_cost`
## and `settle_by` on the entry [method schedule_delayed_trigger]
## returned. The payment goes through [method try_pay] (floating mana
## first, then auto-tapped lands).
func settle_delayed_trigger(pid: int, entry_id: int) -> String:
	var refusal := _act_precheck(pid)
	if refusal != "":
		return refusal
	if priority_player != pid:
		return "you don't have priority"
	var at := _delayed_index(entry_id)
	if at < 0:
		return "no such pending effect"
	var entry: Dictionary = delayed_triggers[at]
	if entry.get("settle_cost") == null:
		return "%s can't be paid off" % entry["desc"]
	if int(entry.get("settle_by", -1)) != pid:
		return "that is not yours to pay off"
	var cost: ManaCost = entry["settle_cost"]
	if not can_afford_cost(pid, cost):
		return "not enough mana to pay %s" % str(cost)
	if not try_pay(pid, cost):
		return "not enough mana to pay %s" % str(cost)
	_rec(self, &"delayed_triggers")
	delayed_triggers.remove_at(at)
	log_line("%s pays %s: %s" % [players[pid].player_name, str(cost), entry["desc"]])
	_emit_state()
	return ""


## The delayed-trigger entries [param pid] may pay off right now — what a
## UI would offer as buttons. See [method settle_delayed_trigger].
func settleable_delayed_triggers(pid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in delayed_triggers:
		if entry.get("settle_cost") != null and int(entry.get("settle_by", -1)) == pid:
			out.append(entry)
	return out


## Drop a delayed trigger that has nothing left to do — a REPEATING one
## whose duration is "the rest of the game" but whose work is spent
## (Cyclopean Tomb with every mired land reverted). Safe to call from
## the entry's own resolution.
func retire_delayed_trigger(entry_id: int) -> void:
	var at := _delayed_index(entry_id)
	if at < 0:
		return
	_rec(self, &"delayed_triggers")
	delayed_triggers.remove_at(at)


func _delayed_index(entry_id: int) -> int:
	for i in delayed_triggers.size():
		if int(delayed_triggers[i]["id"]) == entry_id:
			return i
	return -1


func _delayed_listens(type: int) -> bool:
	for entry in delayed_triggers:
		if (entry["trigger"] as TriggeredAbility).event_type == type:
			return true
	return false


## Put every delayed trigger [param pid] controls that [param event]
## fires on the stack — the once-only ones leaving the queue as they go
## (CR 603.7c). Called by [method dispatch_event] in that player's APNAP
## slot, after their permanents' triggers.
func _dispatch_delayed(pid: int, event: GameEvent) -> void:
	var due: Array[Dictionary] = []
	for entry in delayed_triggers:
		if int(entry["controller"]) != pid:
			continue
		var trig: TriggeredAbility = entry["trigger"]
		if trig.matches(self, entry["source"], event):
			due.append(entry)
	for entry in due:
		if not bool(entry.get("repeats", false)):
			var at := _delayed_index(int(entry["id"]))
			if at >= 0:
				_rec(self, &"delayed_triggers")
				delayed_triggers.remove_at(at)
		var source: CardInstance = entry["source"]
		var item := StackItem.new()
		item.kind = Mtg.StackKind.TRIGGER
		item.card = source
		item.controller = pid
		item.trigger = entry["trigger"]
		item.event = event
		item.delayed = entry
		item.description = "%s — %s" % [
			source.data.card_name if source != null else "Delayed trigger",
			(entry["trigger"] as TriggeredAbility).text]
		_push_trigger(item)


## "Target spell or permanent becomes <colour>." — an INDEFINITE colour
## change (CR 613 layer 5): the Laces, Alchor's Tomb, Aisling Leprechaun.
## [param color_mask] is an Mtg.ManaColor bitmask (0 = colourless). Works
## on a card on the STACK too, and the change rides along when that spell
## resolves into a permanent, exactly as printed.
func set_color(inst: CardInstance, color_mask: int) -> void:
	if inst == null:
		return
	_rec(inst, &"color_override")
	inst.color_override = color_mask
	inst.cur_colors = color_mask
	var names := PackedStringArray()
	for c in Mtg.WUBRG:
		if (color_mask & c) != 0:
			names.append(Mtg.COLOR_NAMES[c])
	log_line("%s becomes %s" % [inst.data.card_name,
		"colorless" if names.is_empty() else " and ".join(names).to_lower()])
	recalculate()
	check_state_based_actions()
	_emit_state()


## TEXT-CHANGING effects (CR 613 layer 3, indefinite): Magical Hack's
## "replace all instances of one basic land type with another", Sleight of
## Mind's colour words, Quarum Trench Gnomes' mana. [param kind] is one of
## "land_type", "color_word", "mana_color"; see CardInstance.text_changes
## for what each one reaches.
func change_text(inst: CardInstance, kind: String, from_value: Variant,
		to_value: Variant) -> void:
	if inst == null:
		return
	_rec(inst, &"text_changes")
	inst.text_changes.append({"kind": kind, "from": from_value, "to": to_value})
	log_line("%s's text changes: %s becomes %s" % [
		inst.data.card_name, str(from_value), str(to_value)])
	recalculate()
	check_state_based_actions()
	_emit_state()


## Flip a coin (CR 705). True = the flipping player WON the flip. Uses
## game.rng, so a seeded game reproduces every flip exactly.
func flip_coin(pid: int) -> bool:
	var won := (rng.randi() % 2) == 0
	log_line("%s flips a coin: %s" % [
		players[pid].player_name, "wins the flip" if won else "loses the flip"])
	return won


## Remove [param inst] from combat (Mijae Djinn's failed flip, Ydwen
## Efreet's, Disharmony). It stops attacking or blocking; anything it was
## blocking alone becomes unblocked, which is what the printed cards say.
## [param unblock_solo_attackers]: the printed exception to CR 509.1h —
## "creatures it was blocking that had become blocked by ONLY that creature
## this combat become unblocked" (False Orders). Without it, the creatures
## it was blocking stay blocked and simply have nothing blocking them, which
## is the default rule.
func remove_from_combat(inst: CardInstance, unblock_solo_attackers := false) -> void:
	if undo_log != null:
		undo_log.record_object(combat)   # every collection may lose it
	var was_blocking: int = int(combat.blocks.get(inst.id, -1))
	# CombatState.forget drops it as attacker, band member, blocked flag and
	# blocker. Whatever it was blocking STAYS blocked (509.1h) unless the
	# card below says otherwise.
	combat.forget(inst.id)
	if unblock_solo_attackers and was_blocking != -1 \
			and combat.blockers_of(was_blocking).is_empty():
		combat.blocked_attackers.erase(was_blocking)
		var freed := find_instance(was_blocking)
		if freed != null:
			log_line("%s is unblocked" % freed.data.card_name)
	recalculate()


## Re-assign an existing blocker to a different attacker mid-combat (False
## Orders, Sorrow's Path). No legality check — the callers do their own,
## because the printed cards override the normal restrictions.
func set_block(blocker: CardInstance, attacker: CardInstance) -> void:
	if blocker == null or attacker == null:
		return
	if undo_log != null:
		undo_log.record_object(combat)
		_rec(blocker, &"blocked_this_turn")
		_rec(blocker, &"blocked_ids_this_turn")
	combat.blocks[blocker.id] = attacker.id
	# RE-POINTED, not added to: *"that creature is now blocking"* is one
	# block, so a creature that was blocking several (CR 509.1b) is left
	# blocking only the one it was pointed at.
	combat.extra_blocks.erase(blocker.id)
	combat.blocked_attackers[attacker.id] = true
	blocker.blocked_this_turn = true
	blocker.blocked_ids_this_turn[attacker.id] = attacker.controller_id
	log_line("%s now blocks %s" % [blocker.data.card_name, attacker.data.card_name])
	recalculate()


## "Gain control of that creature until end of turn" (Disharmony). The
## permanent goes home at cleanup, even if the effect's source is gone.
func gain_control_until_eot(inst: CardInstance, pid: int) -> void:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.controller_id == pid:
		return
	_control_until_eot.append({
		"instance_id": inst.id, "owner_pid": inst.controller_id,
	})
	change_control(inst, pid)


## Move control of a battlefield permanent to [param new_pid] (Control
## Magic). The permanent changes battlefield lists, keeps its timestamp,
## and picks up "summoning sickness" for its new controller (it hasn't
## been under their control since their turn began, CR 302.6).
func change_control(inst: CardInstance, new_pid: int) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD or inst.controller_id == new_pid:
		return
	# "Other players can't gain control of them" (Guardian Beast). Every
	# control change in the engine comes through here, so one gate covers
	# the leashes, the until-EOT borrows and the CR 701.10 exchange.
	if inst.cur_cant_change_control:
		log_line("%s can't change controllers" % inst.data.card_name)
		return
	if undo_log != null:
		_rec(players[inst.controller_id], &"battlefield")
		_rec(players[new_pid], &"battlefield")
		_rec(inst, &"controller_id")
		_rec(inst, &"summoning_sick")
		undo_log.record_object(combat)
	players[inst.controller_id].battlefield.erase(inst)
	inst.controller_id = new_pid
	players[new_pid].battlefield.append(inst)
	inst.summoning_sick = true
	# CR 506.4: a permanent is removed from combat when its controller
	# changes — otherwise a stolen attacker keeps swinging at its new
	# controller, and a stolen blocker keeps fighting for the thief.
	if combat.attackers.has(inst.id) or combat.blocks.has(inst.id):
		# CombatState.forget does all five collections, the one-to-many
		# block map included — spelling four of them out here is how a
		# sixth would get missed.
		combat.forget(inst.id)
	log_line("%s gains control of %s" % [
		players[new_pid].player_name, inst.data.card_name])
	recalculate()


## EXCHANGE control of two battlefield permanents (CR 701.10) — Juxtapose,
## Gauntlets of Chaos and Power Struggle are the pool's three.
##
## This is one helper rather than two [method change_control] calls because
## CR 701.10c makes the exchange ALL-OR-NOTHING: it happens only if both
## permanents are still on the battlefield and each is controlled by a
## different player. Swapping by hand invites the half-trade — the first
## permanent changes seats, the second turns out to be gone, and somebody
## is a permanent up. The pair is also swapped inside a
## [method begin_simultaneous] bracket so an Aura that loses its host, or a
## legend rule the trade triggers, is judged on the finished board rather
## than on the half-done one.
##
## Returns true when the exchange actually happened.
func exchange_control(a: CardInstance, b: CardInstance) -> bool:
	if a == null or b == null or a == b:
		return false
	if a.zone != Mtg.Zone.BATTLEFIELD or b.zone != Mtg.Zone.BATTLEFIELD:
		return false
	var pa := a.controller_id
	var pb := b.controller_id
	if pa == pb:
		return false
	# A permanent nobody else may gain control of (Guardian Beast) stops the
	# WHOLE exchange, not just its own half — otherwise the ban would hand
	# the other permanent over for nothing.
	if a.cur_cant_change_control or b.cur_cant_change_control:
		log_line("%s and %s can't exchange controllers" % [
			a.data.card_name, b.data.card_name])
		return false
	begin_simultaneous()
	change_control(a, pb)
	change_control(b, pa)
	end_simultaneous()
	log_line("%s and %s exchange controllers" % [
		a.data.card_name, b.data.card_name])
	return true


## Reanimate a creature card from a graveyard onto the battlefield under
## [param controller] (Animate Dead's engine half).
func reanimate(inst: CardInstance, controller: int) -> void:
	if inst.zone != Mtg.Zone.GRAVEYARD:
		return
	players[inst.owner_id].graveyard.erase(inst)
	log_line("%s returns from the graveyard under %s's control" % [
		inst.data.card_name, players[controller].player_name])
	_put_on_battlefield(inst, controller)


## Put [param count] counters of [param kind] on a permanent ("+1/+1",
## "-1/-1", ...). Characteristics recompute; -1/-1 deaths fall out of the
## toughness state-based action.
func add_counters(inst: CardInstance, kind: String, count := 1) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	_rec(inst, &"counters")
	inst.counters[kind] = int(inst.counters.get(kind, 0)) + count
	log_line("%s gets %d %s counter(s) (now %d)" % [
		inst.data.card_name, count, kind, inst.counters[kind]])
	recalculate()
	check_state_based_actions()


## Take [param count] counters of [param kind] off a permanent — all of
## them when it carries fewer (Cyclopean Tomb's reversion). Journaled,
## so a resolution may strip a permanent that is neither its source nor
## its target. Characteristics recompute.
func remove_counters(inst: CardInstance, kind: String, count := 1) -> void:
	if inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	var had := int(inst.counters.get(kind, 0))
	if had <= 0 or count <= 0:
		return
	_rec(inst, &"counters")
	var left := had - count
	if left > 0:
		inst.counters[kind] = left
	else:
		inst.counters.erase(kind)
	log_line("%s loses %d %s counter(s) (now %d)" % [
		inst.data.card_name, mini(count, had), kind, maxi(left, 0)])
	recalculate()
	check_state_based_actions()


## Shuffle [param pid]'s GRAVEYARD into their library (Feldon's Cane).
## The graveyard empties; the library is reshuffled with game.rng.
func shuffle_graveyard_into_library(pid: int) -> void:
	var p := players[pid]
	if undo_log != null:
		_rec(p, &"graveyard")
		_rec(p, &"library")
		for inst in p.graveyard:
			_rec(inst, &"zone")
	for inst in p.graveyard:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.graveyard.clear()
	_shuffle(p.library)
	log_line("%s shuffles their graveyard into their library" % p.player_name)
	_emit_state()


## Shuffle [param pid]'s hand into their library (Winds of Change — the
## graveyard stays put, unlike Timetwister's full reset).
func shuffle_hand_into_library(pid: int) -> void:
	var p := players[pid]
	if undo_log != null:
		_rec(p, &"hand")
		_rec(p, &"library")
		for inst in p.hand:
			_rec(inst, &"zone")
	for inst in p.hand:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.hand.clear()
	_shuffle(p.library)
	log_line("%s shuffles their hand into their library" % p.player_name)
	_emit_state()


## Shuffle [param pid]'s library where it stands (Natural Selection's "you
## may have that player shuffle"). Journaled; uses [member rng].
func shuffle_library(pid: int) -> void:
	var p := players[pid]
	_rec(p, &"library")
	_shuffle(p.library)
	log_line("%s shuffles their library" % p.player_name)
	_emit_state()


## Put the top cards of [param pid]'s library back in the order given —
## [param ordered][0] ends on TOP (Natural Selection's "put them back in
## any order"). Every card in [param ordered] must already be one of the
## top [code]ordered.size()[/code] cards, or nothing moves: this reorders
## what a player has looked at, it never fetches. Journaled.
func reorder_top_of_library(pid: int, ordered: Array[CardInstance]) -> void:
	var p := players[pid]
	var n := ordered.size()
	if n == 0 or n > p.library.size():
		return
	var floor_index := p.library.size() - n
	for inst in ordered:
		if p.library.find(inst) < floor_index:
			return
	_rec(p, &"library")
	for inst in ordered:
		p.library.erase(inst)
	for i in range(n - 1, -1, -1):
		p.library.append(ordered[i])
	_emit_state()


## State-based actions (CR 704): checked after every mutation, looped until
## nothing more applies. v0.1 checks: player at 0 or less life loses;
## lethal-damage / zero-toughness creatures die; orphaned auras fall off.
## CR 704.3: state-based actions are checked when a player WOULD receive
## priority — NEVER in the middle of one effect. An effect that hits several
## things AT ONCE (a sweeper's "each creature and each player", a combat
## damage wave) brackets itself with this pair, so nothing is swept until
## all of it has landed. That is what makes two lethal blows SIMULTANEOUS,
## and simultaneous lethal blows to both seats are a draw (CR 104.4b).
##
## Nests: only the outermost [method end_simultaneous] sweeps.
func begin_simultaneous() -> void:
	_defer_depth += 1
	_defer_state_based_actions = true


## Close a [method begin_simultaneous] bracket and sweep if it was the last.
func end_simultaneous() -> void:
	_defer_depth = maxi(_defer_depth - 1, 0)
	if _defer_depth == 0:
		_defer_state_based_actions = false
		check_state_based_actions()


func check_state_based_actions() -> void:
	if game_over or _defer_state_based_actions:
		return
	var acted := true
	while acted:
		acted = false
		# THE LOSS CHECKS ARE COLLECTED, NOT ACTED ON ONE AT A TIME.
		# CR 704.4 performs every applicable state-based action
		# SIMULTANEOUSLY, and CR 104.4b: if all remaining players lose at
		# once, the game is a DRAW. An Earthquake for lethal to both seats
		# used to hand the win to whichever player this loop reached second.
		var losers: Array[int] = []
		var reasons := PackedStringArray()
		for p in players:
			if p.has_lost:
				continue
			# "You don't lose the game for having 0 or less life" (Lich).
			# Under the 1997 ruleset this check moves to the PHASE
			# boundary instead, so a player may drop below 0 and live by
			# regaining it in time (manual p.174) — see _check_lethal_life.
			if p.life <= 0 and not p.cant_lose_to_life \
					and not rules.life_checked_at_phase_end:
				losers.append(p.id)
				reasons.append("life total is 0 or less")
			# POISON (CR 704.5c): ten or more poison counters loses the game.
			elif p.poison >= 10:
				losers.append(p.id)
				reasons.append("ten poison counters")
		if losers.size() >= players.size():
			draw_game("both duelists lost at the same time")
			return
		if losers.size() > 0:
			_lose(losers[0], reasons[0])
			return
		# FAST PASS — the checks that apply to any permanent at all. This
		# whole method runs on every mutation AND every time a player would
		# get priority, so it stays two comparisons per permanent.
		for inst in all_battlefield():
			if inst.is_creature():
				if inst.cur_indestructible and inst.cur_toughness > 0:
					continue   # lethal damage doesn't touch it (CR 700.4)
				if inst.cur_toughness <= 0:
					# Zero toughness is not destruction — regeneration
					# cannot save it (CR 704.5f vs 704.5g).
					log_line("%s has toughness 0 and dies" % inst.data.card_name)
					_move_to_graveyard(inst, true)
					acted = true
					break
				if inst.damage >= inst.cur_toughness:
					# Lethal damage IS destruction — goes through destroy()
					# so regeneration shields apply (CR 704.5g).
					log_line("%s has lethal damage" % inst.data.card_name)
					destroy(inst, true)
					acted = true
					break
			# CONTROL LEASHES: "for as long as you control X" / "for as
			# long as X remains tapped" (Old Man of the Sea, Rubinia
			# Soulsinger, Aladdin, Preacher). Instance state, not a printed
			# clause, so it belongs in the fast pass.
			if inst.controlled_via != -1:
				var leash := find_instance(inst.controlled_via)
				var broken := leash == null or leash.zone != Mtg.Zone.BATTLEFIELD
				if not broken and inst.leash_needs_tapped and not leash.tapped:
					broken = true
				# Live power on both sides (CONTRIBUTING.md rule 5): pumping the
				# stolen creature — or shrinking the thief — ends the leash.
				if not broken and inst.leash_power_capped \
						and inst.cur_power > leash.cur_power:
					broken = true
				if broken:
					log_line("%s returns to its owner — the leash broke" % \
						inst.data.card_name)
					if undo_log != null:
						_rec(inst, &"controlled_via")
						_rec(inst, &"leash_needs_tapped")
						_rec(inst, &"leash_power_capped")
					inst.controlled_via = -1
					inst.leash_needs_tapped = false
					inst.leash_power_capped = false
					if inst.controller_id != inst.owner_id:
						change_control(inst, inst.owner_id)
					acted = true
					break
		if acted:
			continue
		# SLOW PASS — the printed clauses only a handful of cards carry.
		# _sba_watch (rebuilt with the battlefield cache) holds exactly the
		# permanents with one, so a board of lands and vanilla creatures
		# never enters this loop at all.
		for inst in _sba_watch:
			if inst.zone != Mtg.Zone.BATTLEFIELD:
				continue   # left the battlefield since the index was built
			# THE LEGEND RULE, 1997 flavor: while two or more LEGENDARY
			# permanents with the same name are on the battlefield, the
			# NEWEST one is buried (the era's "first in time, first in
			# right" rule — not the modern controller-chooses 704.5j).
			# Timestamp = position in _battlefield_order.
			if (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0:
				var doomed := _newest_duplicate_legend(inst.data.card_name)
				if doomed != null:
					log_line("%s is buried — the legend rule (a %s already in play)" % [
						doomed.data.card_name, doomed.data.card_name])
					_move_to_graveyard(doomed, true)
					acted = true
					break
			# "When you control a Dwarf, sacrifice this" (Goblins of the
			# Flarg) — the mirror of the clause below.
			if inst.data.sacrifice_if_you_control_subtype != "":
				var hated := inst.data.sacrifice_if_you_control_subtype
				for other in players[inst.controller_id].battlefield:
					if other != inst and other.is_creature() and other.has_subtype(hated):
						log_line("%s is sacrificed — its controller has a %s" % [
							inst.data.card_name, hated.capitalize()])
						sacrifice_permanent(inst)
						acted = true
						break
				if acted:
					break
			# "When you control no Islands, sacrifice this" (Sea Serpent,
			# Dandan, Merchant Ship). Printed as a state trigger; checked
			# here because a state-based check fires at exactly the same
			# moments and needs no stack.
			if inst.data.sacrifice_if_no_land_type != "":
				var kind := inst.data.sacrifice_if_no_land_type
				var has_one := false
				for land in players[inst.controller_id].battlefield:
					if land.is_land() and land.has_subtype(kind):
						has_one = true
						break
				if not has_one:
					log_line("%s is sacrificed — its controller has no %s" % [
						inst.data.card_name, kind.capitalize()])
					sacrifice_permanent(inst)
					acted = true
					break
			# The general "When <condition>, sacrifice this permanent"
			# (Jihad). Same state-trigger-as-SBA treatment as the clause
			# above; the predicate lives on the card.
			if inst.data.sacrifice_condition.is_valid() \
					and inst.data.sacrifice_condition.call(self, inst):
				log_line("%s is sacrificed — its condition is no longer met" % \
					inst.data.card_name)
				sacrifice_permanent(inst)
				acted = true
				break
			# THE WORLD RULE (CR 704.5k): while two or more WORLD
			# permanents are on the battlefield, all but the newest are
			# put into their owners' graveyards. Legends' world
			# enchantments (Concordant Crossroads, Gravity Sphere,
			# Living Plane, The Abyss...) police each other by name AND
			# across names — unlike the legend rule, which is per-name.
			if (inst.data.supertypes & Mtg.Supertype.WORLD) != 0:
				var superseded := _superseded_world_permanent()
				if superseded != null:
					log_line("%s is put into the graveyard — the world rule" % \
						superseded.data.card_name)
					_move_to_graveyard(superseded, false)
					acted = true
					break
			# inst.is_aura(), not the printed answer: an Aura that came back
			# "as a non-Aura enchantment" (Takklemaggot) is attached to
			# nothing and is nobody's orphan.
			if inst.is_aura():
				var host := find_instance(inst.attached_to)
				if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
					log_line("%s is no longer attached and is put into the graveyard" % inst.data.card_name)
					_move_to_graveyard(inst, false)
					acted = true
					break
				# CR 704.5m: the host must still be something this Aura
				# COULD enchant — a Mishra's Factory whose animation expired
				# is no longer a creature, so Firebreathing falls off.
				# can_attach_to asks only what the host IS: protection is the
				# clause below (which knows the Wards' self-exemption), and a
				# host that gained shroud keeps its Aura (Spectral Cloak
				# grants shroud to the very creature it enchants).
				# Animate Dead's kind is exempt: the modern oracle has it
				# swap "enchant creature card in a graveyard" for "enchant
				# creature put onto the battlefield with this Aura" as it
				# enters, so its host is legally on the battlefield.
				if not inst.data.aura_reanimates \
						and not inst.data.aura_target.can_attach_to(self, host):
					log_line("%s can no longer enchant %s and is put into the graveyard" % [
						inst.data.card_name, host.data.card_name])
					host.attachments.erase(inst.id)
					_move_to_graveyard(inst, false)
					acted = true
					break
				# Protection's E of DEBT (CR 702.16d): a host that gained
				# protection from the aura's color sheds it — EXCEPT the
				# protection this very aura grants ("This effect doesn't
				# remove this Aura" — the Wards).
				if (host.cur_protection & inst.cur_colors
						& ~inst.data.aura_grants_protection) != 0:
					log_line("%s falls off %s (protection)" % [
						inst.data.card_name, host.data.card_name])
					host.attachments.erase(inst.id)
					_move_to_graveyard(inst, false)
					acted = true
					break


## World-rule helper (CR 704.5k): if 2+ WORLD permanents are on the
## battlefield, return the OLDEST one (the one that loses); else null.
## Repeated SBA passes bury them one at a time until only the newest is
## left.
func _superseded_world_permanent() -> CardInstance:
	var worlds: Array[CardInstance] = []
	for id in _battlefield_order:   # oldest → newest
		var inst: CardInstance = _instances[id]
		if inst.zone == Mtg.Zone.BATTLEFIELD \
				and (inst.data.supertypes & Mtg.Supertype.WORLD) != 0:
			worlds.append(inst)
	return worlds[0] if worlds.size() >= 2 else null


## Is [param inst] currently sustaining something that would end if it
## untapped — a control leash, or a "for as long as this remains tapped"
## effect it remembers? Used by the untap step for permanents that say
## "you may choose not to untap this".
func _is_sustaining(inst: CardInstance) -> bool:
	if inst.memory.has("holding"):
		var held := find_instance(int(inst.memory["holding"]))
		if held != null and held.zone == Mtg.Zone.BATTLEFIELD:
			return true
	# Tawnos's Coffin keeps its prisoner in exile only while it stays tapped.
	if inst.memory.has("buried"):
		var buried := find_instance(int(inst.memory["buried"]))
		if buried != null and buried.zone == Mtg.Zone.EXILE:
			return true
	for other in all_battlefield():
		if other.controlled_via == inst.id:
			return true
	return false


## Take control of [param victim] "for as long as" [param leash] stays on
## the battlefield (and, with [param needs_tapped], stays tapped). The
## engine hands the permanent back through a state-based action the
## instant the condition fails.
## [param power_capped]: the leash ALSO ends the moment the held creature's
## power exceeds the leash's — Old Man of the Sea's *"and that creature's
## power remains less than or equal to this creature's power"*.
func gain_control_leashed(victim: CardInstance, leash: CardInstance,
		needs_tapped := false, power_capped := false) -> void:
	if victim.zone != Mtg.Zone.BATTLEFIELD or leash.zone != Mtg.Zone.BATTLEFIELD:
		return
	if undo_log != null:
		_rec(victim, &"controlled_via")
		_rec(victim, &"leash_needs_tapped")
		_rec(victim, &"leash_power_capped")
	victim.controlled_via = leash.id
	victim.leash_needs_tapped = needs_tapped
	victim.leash_power_capped = power_capped
	if victim.controller_id != leash.controller_id:
		change_control(victim, leash.controller_id)


## Every untap CAP category a permanent belongs to. A permanent can be
## several at once — an artifact creature is capped by BOTH Damping Field
## and Smoke, and an animated Mishra's Factory is a land AND a creature —
## so the untap step must check them all and count against each.
static func _untap_kinds(inst: CardInstance) -> Array[String]:
	var kinds: Array[String] = []
	if inst.is_land():
		kinds.append("land")
	if inst.is_type(Mtg.CardType.ARTIFACT):
		kinds.append("artifact")
	if inst.is_creature():
		kinds.append("creature")
	return kinds


## Condemn [param inst] to be destroyed at the beginning of the next end
## step (Berserk, Stone Giant). Regeneration applies — it is a
## destruction, not a sacrifice.
## [param only_if_attacked]: Berserk's "destroy that creature IF IT
## ATTACKED this turn" — the condition belongs to the delayed trigger, not
## to the moment the spell resolved, so a precombat-main Berserk still
## kills the creature that goes on to attack.
## [param as_sacrifice]: the printed word is "sacrifice", not "destroy"
## (Dragon Whelp's fourth breath) — regeneration and indestructible do not
## apply (CR 701.17).
func doom_at_next_end_step(inst: CardInstance, only_if_attacked := false,
		only_if_it_did_not_attack := false, as_sacrifice := false) -> void:
	if _end_step_doom.has(inst.id):
		if not only_if_attacked and not only_if_it_did_not_attack:
			_end_step_doom_if_attacked.erase(inst.id)   # unconditional wins
			_end_step_doom_unless_attacked.erase(inst.id)
		if as_sacrifice:
			_end_step_doom_sacrifice[inst.id] = true
		return
	_end_step_doom.append(inst.id)
	if only_if_attacked:
		_end_step_doom_if_attacked[inst.id] = true
	if only_if_it_did_not_attack:
		_end_step_doom_unless_attacked[inst.id] = true
	if as_sacrifice:
		_end_step_doom_sacrifice[inst.id] = true


## "Destroy it at the beginning of the next end step if it didn't attack
## this turn" (Nettling Imp) — the mirror image of Berserk's clause.
func doom_at_next_end_step_if_it_did_not_attack(inst: CardInstance) -> void:
	doom_at_next_end_step(inst, false, true)


## Legend-rule helper: if 2+ battlefield permanents share [param legend_name],
## return the NEWEST (latest in timestamp order); else null.
func _newest_duplicate_legend(legend_name: String) -> CardInstance:
	var seen := 0
	var newest: CardInstance = null
	for id in _battlefield_order:   # oldest → newest
		var inst: CardInstance = _instances[id]
		if inst.zone == Mtg.Zone.BATTLEFIELD and inst.data.card_name == legend_name:
			seen += 1
			newest = inst
	return newest if seen >= 2 else null


## End the game in a DRAW (CR 104.4 — Divine Intervention). Nobody wins:
## [member winner] stays -1 and [member is_draw] records why.
func draw_game(reason: String) -> void:
	if game_over:
		return
	game_over = true
	is_draw = true
	winner = -1
	log_line("The game is a draw: %s" % reason)
	if not _probing:
		game_ended.emit(-1)
	_emit_state()


## PUBLIC loss: a card says "you lose the game" (Lich). Same path as every
## other loss condition.
func lose_game(pid: int, reason: String) -> void:
	_lose(pid, reason)


## CONCEDE — `@MENU_TERRITORY` entry 24 (`docs/duel-todo.md` §6.3).
##
## `Duel.hlp`, topic **Territory**: *"**Concede** announces to your
## opponent that you're giving up, accepting a loss rather than continue
## this duel. You must confirm this decision."* The confirmation is the
## menu's own entry 25, `Yes, I'm sure`; it belongs to the UI, and by the
## time this is called the player has already given it.
##
## CR 104.3a — *"A player can concede the game at any time. A player who
## concedes leaves the game immediately."* AT ANY TIME is the whole rule:
## it does not use the stack, it does not wait for priority, and it is not
## something an opponent can respond to. So this refuses only what is
## already over.
##
## Three cards in the 1997 pool offer conceding as a CHOICE rather than as
## a menu command — `@DEMONIC_ATTORNEY` (`Program/promptsX1.txt:121`),
## `@BRONZE_TABLET` (`prompts.txt:151`) and `@TEMPEST_EFREET`
## (`prompts.txt:877`) each print `Concede game.` as an option — which is
## why this is an engine action and not a screen one.
func concede(pid: int) -> String:
	if game_over:
		return "the duel is already over"
	if pid < 0 or pid >= players.size():
		return "no such player"
	_lose(pid, "conceded")
	return ""


func _lose(pid: int, reason: String) -> void:
	if players[pid].has_lost:
		return
	players[pid].has_lost = true
	game_over = true
	winner = opponent_of(pid)
	log_line("%s loses: %s. %s wins!" % [
		players[pid].player_name, reason, players[winner].player_name])
	if not _probing:
		game_ended.emit(winner)
	_emit_state()


## Offer [param event] to every triggered ability on the battlefield, in
## APNAP order: the active player's triggers go on the stack first so the
## non-active player's resolve first (CR 603.3b). Also mirrors the event
## to the [signal event_occurred] signal for UIs.
## [param also_listen]: a card that just LEFT the battlefield but whose
## triggers still see this event — dying creatures hear their own
## dies-triggers (CR 603.6b look-back; Su-Chi taught the engine this) —
## or a SPELL on the stack hearing its own SPELL_CAST ("When you cast
## this spell", Mana Vortex), which listens with its controller's seat.
func dispatch_event(type: int, data: Dictionary, also_listen: CardInstance = null) -> void:
	var event := GameEvent.new(type, data)
	if not _probing:
		event_occurred.emit(event)
	if game_over:
		return
	# PERFORMANCE: most events (damage, draws, taps) have no listener at
	# all. all_battlefield() keeps an index of the event types the current
	# battlefield subscribes to, so the common case costs one Dictionary
	# probe instead of building a listener list. A departing card that must
	# still hear its own trigger (also_listen) always takes the long path.
	# GRAVEYARD listeners (Nether Shadow) — only the turn-based events reach
	# them, so the dispatcher's hot path (damage, taps, draws) is untouched.
	#
	# APNAP (CR 603.3b) HOLDS HERE ONLY BECAUSE EVERY GRAVEYARD TRIGGER IN
	# THE POOL IS SELF-SCOPED. These go on the stack in seat order and
	# BEFORE the battlefield pass, so they resolve after every battlefield
	# trigger. That is legal while they can only belong to the ACTIVE player
	# — "at the beginning of YOUR upkeep" (Nether Shadow, Hazezon Tamar's
	# delayed sandstorm), where the order among one player's own triggers is
	# that player's choice. A graveyard trigger that fired on the OPPONENT's
	# upkeep or on a shared end step would need this loop folded into the
	# APNAP pass below.
	if type == Mtg.EventType.UPKEEP_START or type == Mtg.EventType.END_STEP_START:
		for p in players:
			var crawl: Array[CardInstance] = []
			crawl.append_array(p.graveyard)
			crawl.append_array(p.exile)
			for buried in crawl:
				var listeners: Array[TriggeredAbility] = \
					buried.data.graveyard_triggers if buried.zone == Mtg.Zone.GRAVEYARD \
					else buried.data.exile_triggers
				for grave_trig in listeners:
					if not grave_trig.matches(self, buried, event):
						continue
					var grave_item := StackItem.new()
					grave_item.kind = Mtg.StackKind.TRIGGER
					grave_item.card = buried
					grave_item.controller = buried.owner_id
					grave_item.trigger = grave_trig
					grave_item.event = event
					grave_item.description = "%s — %s" % [
						buried.data.card_name, grave_trig.text]
					_push_trigger(grave_item)
	all_battlefield()
	var delayed_listen := _delayed_listens(type)
	if also_listen == null and not delayed_listen and not _trigger_index.has(type):
		return
	# APNAP: the active player's permanents are offered the event first, so
	# their triggers go on the stack first and resolve last (CR 603.3b) —
	# and each player's DELAYED triggers (CR 603.7) go on with their
	# permanents', after them: the order among one player's own triggers
	# is that player's to choose (CR 603.3b), and this is the choice.
	var seats: Array[int] = [active_player, opponent_of(active_player)]
	for seat_index in seats.size():
		var pid := seats[seat_index]
		var listeners: Array[CardInstance] = players[pid].battlefield.duplicate()
		if also_listen != null and not listeners.has(also_listen) \
				and not players[seats[0]].battlefield.has(also_listen):
			# A SPELL hearing its own cast (Mana Vortex) listens with its
			# controller's seat, so APNAP holds for it; a card that just
			# LEFT the battlefield is offered with the last seat, after
			# every permanent — the order every dies-trigger stack in the
			# suite is pinned to.
			var seat_for_it: int = also_listen.controller_id \
				if also_listen.zone == Mtg.Zone.STACK else seats[seats.size() - 1]
			if pid == seat_for_it:
				listeners.append(also_listen)
		for inst in listeners:
			if inst.cur_abilities_silenced:
				continue   # Titania's Song: it lost all its abilities
			# The LIVE list: printed triggers plus whatever a static
			# granted (Energy Flux's tax rides on each artifact).
			for trig in inst.cur_triggered_abilities:
				if trig.matches(self, inst, event):
					if trig.is_mana_trigger:
						# Triggered mana abilities skip the stack entirely
						# (CR 605.1b) — their mana must be usable mid-payment.
						trig.on_resolve.call(self, inst, event)
						continue
					var item := StackItem.new()
					item.kind = Mtg.StackKind.TRIGGER
					item.card = inst
					item.controller = inst.controller_id
					item.trigger = trig
					item.event = event
					item.description = "%s — %s" % [inst.data.card_name, trig.text]
					_push_trigger(item)
		if delayed_listen:
			_dispatch_delayed(pid, event)


## Put one triggered ability on the stack — unless it TARGETS and has no
## legal target, in which case it is removed instead (CR 603.3d). A
## targeted trigger's controller names the target here, as it goes on the
## stack, and a modal trigger's controller announces the mode first (CR
## 603.3c) — see [method _arm_trigger_targets].
func _push_trigger(item: StackItem) -> void:
	if not _arm_trigger_targets(item):
		log_line("Trigger: %s — no legal target, removed (CR 603.3d)"
			% item.description)
		return
	_rec_stack_push()
	item.id = _next_stack_id
	_next_stack_id += 1
	stack.append(item)
	log_line("Trigger: %s" % item.description)


# ------------------------------------------------- targeted TRIGGERS --
#
# CR 603.3d: a triggered ability with a target chooses it AS IT IS PUT ON
# THE STACK, and is removed from the stack instead when no legal target
# exists. The choice is the trigger's controller's. A heuristic or AI seat
# answers on the spot, inside whatever mutation fired the trigger (a
# creature dying in combat, a step beginning) — its answer_* is pure, so
# that is safe. A HUMAN seat cannot be asked there: nothing can pause a
# combat-damage wave to open a dialog. So for a seat that wants to be
# asked the trigger goes on with a PROVISIONAL pick and
# [member StackItem.target_held] set, and the moment a player would
# receive priority (CR 603.3 — exactly when the rules put triggers on the
# stack) [method _hold_trigger_targets] puts the question to that seat
# through the cost hold's record-and-replay: the duel is held open on
# MtgGame.awaiting_choice, and answer_choice re-runs the pass with the
# answer parked. Nothing has resolved in between, so re-running is safe.
#
# During a PROBE (the pre-flight, an AI search) no seat is asked: the
# ranked list's first entry is taken silently. It is what the AI and the
# heuristic would answer anyway (PlayerChoice.ordered), and asking the
# human seat inside a probe would put the question on the pre-flight's
# list and hold the RESOLUTION open on it — a question the hold below is
# about to ask properly once the resolution is over.

## Announce the mode of a modal trigger and name the target of a targeted
## trigger as it goes on the stack — mode first (CR 603.3c, 700.2d). True
## when the trigger may go on (context-only triggers always may); false
## when it targets and nothing is legal (CR 603.3d).
func _arm_trigger_targets(item: StackItem) -> bool:
	var trig := item.trigger
	if trig == null or (trig.target_spec == null and trig.modes.is_empty()):
		return true
	var refs: Array[TargetRef] = []
	if trig.target_spec != null:
		refs = _trigger_target_candidates(item)
		if refs.is_empty():
			return false
	if not trig.modes.is_empty():
		var mode_q := _trigger_mode_question(item)
		if _seat_will_be_held(mode_q):
			item.target_held = true
			_set_trigger_mode(item, mode_q.hint)   # provisional
		else:
			_set_trigger_mode(item, mode_q.hint if _probing
				else _ask_trigger_mode(item, mode_q))
	if trig.target_spec == null:
		return true
	var question := _trigger_question(item, refs)
	if item.target_held or _seat_will_be_held(question):
		item.target_held = true
		_set_trigger_target(item, refs[0])   # provisional; replaced at priority
		return true
	var ref: TargetRef = refs[0] if _probing \
		else _ask_trigger_target(item, refs, question)
	_set_trigger_target(item, ref)
	return true


## The mode question of a modal trigger: an OPTION list of its labels,
## hinted with the trigger's own preference (TriggeredAbility.mode_hint).
func _trigger_mode_question(item: StackItem) -> PlayerChoice:
	var trig := item.trigger
	var name: String = item.card.data.card_name
	var prompt: String = trig.mode_prompt
	if prompt == "":
		prompt = "%s: choose one" % name
	var question := _turn_question(item.controller, name,
		PlayerChoice.Kind.OPTION, prompt)
	question.options = trig.modes.duplicate()
	var hint := 0
	if trig.mode_hint.is_valid():
		hint = int(trig.mode_hint.call(self, item.card, item.event))
	question.hint = clampi(hint, 0, trig.modes.size() - 1)
	return question


## Ask the trigger's controller which mode, scoped to the trigger's card.
func _ask_trigger_mode(item: StackItem, question: PlayerChoice) -> int:
	var pid := item.controller
	var outer := _turn_source
	_turn_source = item.card.data.card_name
	var index := agents[pid].choose_option(self, pid, question.options,
		question.prompt, int(question.hint))
	_turn_source = outer
	return clampi(index, 0, question.options.size() - 1)


## Record the announced mode and say so in the stack line.
func _set_trigger_mode(item: StackItem, mode: int) -> void:
	item.mode = mode
	item.description = "%s — %s (%s)" % [
		item.card.data.card_name, item.trigger.text, item.trigger.modes[mode]]


## Every legal target of [param item]'s trigger right now, ranked with the
## trigger's own order (TriggeredAbility.target_order) — first is best for
## its controller.
func _trigger_target_candidates(item: StackItem) -> Array[TargetRef]:
	var trig := item.trigger
	var refs: Array[TargetRef] = trig.target_spec.legal_targets(self, item.card)
	if trig.target_order.is_valid() and refs.size() > 1:
		var order: Callable = trig.target_order
		var source: CardInstance = item.card
		refs.sort_custom(func(a: TargetRef, b: TargetRef) -> bool:
			return bool(order.call(self, source, a, b)))
	return refs


## The question a targeted trigger puts to its controller: a CARD list
## when every candidate is a card, an OPTION list of names when a player
## is among them ("target player" — Axelrod Gunnarson, Relic Bind). Ranked
## (PlayerChoice.ordered), so the first entry is the hint.
func _trigger_question(item: StackItem, refs: Array[TargetRef]) -> PlayerChoice:
	var trig := item.trigger
	var prompt: String = trig.target_prompt
	if prompt == "":
		prompt = "Select %s." % trig.target_spec.description
	var name: String = item.card.data.card_name
	var cards: Array[CardInstance] = []
	for ref in refs:
		if ref.is_player or ref.is_damage or ref.is_ability:
			cards.clear()
			break
		cards.append(find_instance(ref.instance_id))
	if not cards.is_empty():
		var card_q := _turn_question(item.controller, name,
			PlayerChoice.Kind.CARD, prompt)
		card_q.candidates = cards
		card_q.ordered = true
		card_q.hint = cards[0]
		return card_q
	var labels: Array[String] = []
	for ref in refs:
		labels.append(target_label(ref))
	var option_q := _turn_question(item.controller, name,
		PlayerChoice.Kind.OPTION, prompt)
	option_q.options = labels
	option_q.ordered = true
	option_q.hint = 0
	return option_q


## Will [param question] be HELD for its seat rather than answered on the
## spot — the cost hold's own gate ([method _hold_cost_choice]), asked
## without counting the question.
func _seat_will_be_held(question: PlayerChoice) -> bool:
	if not interactive_choices or _probing or awaiting_choice != null:
		return false
	var pid := question.pid
	if pid < 0 or pid >= agents.size():
		return false
	return agents[pid].wants_to_be_asked() and agents[pid].can_answer(question)


## Ask the trigger's controller which of [param refs] it targets, scoped
## to the trigger's card the way a turn-based question is. Never optional:
## a declined or stale answer is the first candidate, the one the order put
## there.
func _ask_trigger_target(item: StackItem, refs: Array[TargetRef],
		question: PlayerChoice) -> TargetRef:
	var pid := item.controller
	var outer := _turn_source
	_turn_source = item.card.data.card_name
	var index := 0
	if question.kind == PlayerChoice.Kind.CARD:
		var cards: Array[CardInstance] = question.candidates
		var picked := agents[pid].choose_card(self, pid, cards, question.prompt,
			false, false, true)
		if picked != null and cards.has(picked):
			index = cards.find(picked)
	else:
		index = agents[pid].choose_option(self, pid, question.options,
			question.prompt, 0, false, true)
	_turn_source = outer
	return refs[clampi(index, 0, refs.size() - 1)]


## Record [param ref] as the trigger's target — the same two fields a
## single-target ability carries — and say so in the stack line.
func _set_trigger_target(item: StackItem, ref: TargetRef) -> void:
	var targets: Array[TargetRef] = [ref]
	item.targets = targets
	item.target_groups = [[ref]]
	var chosen := ""
	if not item.trigger.modes.is_empty():
		chosen = "%s, " % item.trigger.modes[item.mode]
	item.description = "%s — %s (%stargeting %s)" % [
		item.card.data.card_name, item.trigger.text, chosen, target_label(ref)]


## The moment a player would receive priority: put every HELD trigger's
## mode and target questions to its seat, in stack order. True when the
## duel is now held open on one of them (MtgGame.awaiting_choice) — the
## caller must then stop short of giving priority; answer_choice re-runs
## this pass. [param actor] is the player keeping priority after their
## own action (CR 117.3c — [method _resume_priority]), or -1 when
## priority is being opened afresh ([method _open_priority]); it is what
## the replay hands priority back to. A held trigger whose legal targets
## have all gone in the meantime is removed from the stack (CR 603.3d —
## the rules put it there only now).
func _hold_trigger_targets(actor := -1) -> bool:
	var held: Array[StackItem] = []
	for item in stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.target_held:
			held.append(item)
	if held.is_empty():
		return false
	var replay := {"kind": "trigger_target", "pid": actor}
	_begin_cost_choices()
	for item in held:
		var trig := item.trigger
		var refs: Array[TargetRef] = []
		if trig.target_spec != null:
			refs = _trigger_target_candidates(item)
			if refs.is_empty():
				log_line("Trigger: %s — no legal target, removed (CR 603.3d)"
					% item.description)
				_rec(self, &"stack")
				stack.erase(item)
				item.target_held = false
				continue
		if not trig.modes.is_empty():
			# The mode is announced before the target (CR 603.3c, 700.2d).
			var mode_q := _trigger_mode_question(item)
			if _hold_cost_choice(mode_q, replay):
				return true
			_set_trigger_mode(item, _ask_trigger_mode(item, mode_q))
		if trig.target_spec == null:
			continue
		var question := _trigger_question(item, refs)
		if _hold_cost_choice(question, replay):
			return true
		_set_trigger_target(item, _ask_trigger_target(item, refs, question))
	# Every question answered: the picks are final.
	for item in held:
		item.target_held = false
	return false


## Is the targeted trigger [param item] about to resolve with an ILLEGAL
## target (CR 608.2b — it fizzles)?
func _trigger_target_illegal(item: StackItem) -> bool:
	var spec: TargetSpec = item.trigger.target_spec
	if spec == null:
		return false
	if item.targets.is_empty():
		return true
	return not spec.is_legal(self, item.targets[0], item.card)


## Recalculate after a permanent's TAPPED state changed.
##
## PERFORMANCE: tapping is by far the most frequent state change in a game
## (every land, every turn), and the only way a tap can alter any current
## characteristic is through a STATIC ability that reads tapped state
## (Castle's "untapped creatures you control get +0/+2", Meekstone). Every
## other input to the pipeline — printed values, counters, floating
## until-end-of-turn effects, the per-instance permanent modifiers — is
## blind to it, and the game-level fields the pipeline resets are written
## only by statics. So with no static anywhere on the battlefield the whole
## pass is provably a no-op and only the UI refresh is needed. Any path
## that adds a static to the battlefield recalculates on its own.
func _recalculate_for_tap_change() -> void:
	if battlefield_with_statics().is_empty():
		_emit_state()
		return
	recalculate()


## Re-derive all current characteristics (continuous-effects pipeline).
func recalculate() -> void:
	continuous.recalculate(self)
	_emit_state()


## Append one line to the game log and mirror it on [signal log_appended].
## The log is the engine's audit trail: every mutation helper writes one,
## which is what makes a bug report reproducible from a seed plus a log.
func log_line(msg: String) -> void:
	if _probing:
		return   # a probe is rewound; its log lines never happened
	log_lines.append(msg)
	log_appended.emit(msg)


func _emit_state() -> void:
	if _probing:
		return
	_announce_revealed_tops()
	state_changed.emit()


## "Players play with the top card of their libraries revealed" (Field of
## Dreams): the top card of [param pid]'s library when it is public, else
## null. The single read for the duel screen and the AI — a library's top
## is otherwise hidden information.
func revealed_top_card(pid: int) -> CardInstance:
	if not players[pid].top_card_revealed or players[pid].library.is_empty():
		return null
	return players[pid].library[-1]


## Log a revealed library top the first time it is that card, so the
## reveal is a matter of record for both seats (a draw, a shuffle or a
## Millstone puts a new card there). Called as state is published, never
## from a probe (which is rewound).
func _announce_revealed_tops() -> void:
	for pid in players.size():
		var top := revealed_top_card(pid)
		var top_id := top.id if top != null else -1
		if top_id == _announced_tops[pid]:
			continue
		if undo_log != null:
			_rec(self, &"_announced_tops")
		_announced_tops[pid] = top_id
		if top != null:
			log_line("The top card of %s's library is revealed: %s" % [
				players[pid].player_name, top.data.card_name])


## The card whose resolution is running right now — or, outside one, whose
## COST is being paid ([member _cost_source]). "" when neither. The
## DecisionAgent funnel stamps it on every question so a UI can park an
## answer FOR ONE CARD and never have it served to another.
func current_resolution_source() -> String:
	if _resolving_source != "":
		return _resolving_source
	return _cost_source if _cost_source != "" else _turn_source


## Every target the object being resolved right now chose, FLAT and in slot
## order — the same list [member StackItem.targets] holds. Empty outside a
## resolution.
##
## Why this exists: one targeting effect owns one target slot, so a card
## whose two slots take DIFFERENT specs ("target artifact, creature, or land
## you control AND target permanent an opponent controls") is two effects,
## and the effect that does the work has to see the OTHER slot. mage-go's
## `EffectContext.Targets` hands every effect the whole spell's target list
## for exactly this reason; this is that, without changing the signature
## every effect in the pool already implements.
##
## Cards read it; nothing writes it. Gauntlets of Chaos is the pool's first
## user. A TARGETED TRIGGER's one target (TriggeredAbility.targeting) is
## read here too, by its on_resolve callable — Oubliette's prisoner,
## Erhnam Djinn's forestwalker.
func current_targets() -> Array:
	return _resolving_targets


## The mode the modal trigger being resolved right now was put on the
## stack with (TriggeredAbility.modal — an index into its modes; CR
## 603.3c), read by its on_resolve callable. Relic Bind is the pool's
## reader. 0 outside one.
func current_mode() -> int:
	return _resolving_mode


## The delayed-trigger entry (see [member delayed_triggers]) whose
## trigger is resolving right now — its `memory` is the state a
## repeating delayed trigger keeps between firings (Cyclopean Tomb's
## list of mired lands). Empty outside a delayed trigger's resolution.
## A repeating entry is looked up in the queue by id, so the Dictionary
## returned is the live one even after a journal rewind replaced the
## queue's contents.
func current_delayed() -> Dictionary:
	if _resolving_delayed.is_empty():
		return _resolving_delayed
	var at := _delayed_index(int(_resolving_delayed.get("id", -1)))
	return delayed_triggers[at] if at >= 0 else _resolving_delayed


## Who controls the object being resolved right now, or -1 outside a
## resolution. Psychic Purge's "a spell or ability an OPPONENT controls
## causes you to discard this card" is the pool's only reader.
func current_resolution_controller() -> int:
	return _resolving_controller


## WHAT THE COST OF THE ABILITY BEING RESOLVED ATE — the key an effect wants
## out of [member StackItem.cost_paid], or [param fallback] when this
## resolution paid no such cost.
##
## The four keys in use: `_sacrificed_toughness` (Diamond Valley, Life
## Chisel), `_exiled_mana_value` (Necropolis), `_discarded_types` (Land's
## Edge); `_sacrificed_power`, `_exiled_name` and `_discarded_name` ride
## along for the next card that wants them.
##
## THIS IS PER ACTIVATION, which is the whole reason it is a method and not
## a look in `source.memory`: the record belongs to the object on the stack,
## not to the permanent that put it there, and every one of those four cards
## has a cheap enough cost to have two activations waiting at once. See
## [member StackItem.cost_paid].
func cost_paid(key: String, fallback: Variant = 0) -> Variant:
	return _resolving_cost.get(key, fallback)


## Is the question being asked right now part of a COST (CR 601.2h) rather
## than part of a resolution (CR 608)? Stamped on every [PlayerChoice] by the
## funnel: the two are held open by different machinery and wear different
## 1997 words. See the COST HOLD block above.
func is_paying_cost() -> bool:
	return _cost_source != ""


## File one answered mid-resolution question (docs/duel-todo.md §1.3).
## Called by the DecisionAgent funnel, never by cards.
## [param seat_wanted_it] is the asked seat's own
## [method DecisionAgent.wants_to_be_asked]: when it is true and the answer
## did NOT come from the player, the question goes on the unanswered ledger
## and into the log, because a decision taken on a human's behalf should be
## visible rather than invisible.
func record_choice(choice: PlayerChoice, seat_wanted_it := false) -> void:
	if _probing:
		# A probe exists ONLY to collect the questions: they go on the
		# resolution's list (which _preflight reads and the rewind then
		# clears) and nowhere else. No log line, no ledger, no signal —
		# none of this has happened yet.
		_resolving_choices.append(choice)
		return
	choice_log.append(choice)
	if _resolving_source != "":
		_resolving_choices.append(choice)
	if seat_wanted_it and not choice.answered_by_player:
		unanswered_choices.append(choice)
		# SIMPLIFIED: the engine cannot pause a resolution to ask, so it
		# says out loud what it decided instead. Ledgered in
		# docs/ROADMAP.md ("mid-resolution choices").
		log_line("(decided for %s) %s" % [
			players[choice.pid].player_name, choice.describe()])
	choice_requested.emit(choice)


# ---------------------------------------------------------- turn structure --

## Give priority to the active player at the start of a step / after a
## resolution (CR 117.3a-b).
## The player who cast a spell, activated an ability (a mana ability
## included) or took a special action keeps priority afterward (CR
## 117.3c) — which is "the next time a player would receive priority"
## (CR 603.3) for every trigger the action fired, so a human seat's held
## trigger question (Relic Bind, as the enchanted artifact is tapped for
## mana) is put HERE, before the actor may act again. Nothing else of
## [method _open_priority] applies: no state-based sweep (the action's own
## helpers did that), no damage window, and priority stays with the
## actor rather than going to the active player.
func _resume_priority(pid: int) -> void:
	priority_player = pid
	_passes = 0
	if _hold_trigger_targets(pid):
		return
	_emit_state()


func _open_priority() -> void:
	# CR 704.3: state-based actions are checked whenever a player WOULD
	# receive priority — this is that moment. Most mutation helpers already
	# check eagerly, but some turn-based actions (the end-of-combat and
	# end-step dooms) destroy permanents outside those paths, and their
	# fallout (orphaned auras, a creature at 0 toughness) must be swept
	# before anyone may respond.
	check_state_based_actions()
	# CR 603.3: triggered abilities are put on the stack the next time a
	# player would receive priority — which is when a targeted trigger's
	# controller names its target (CR 603.3d). A human seat's question is
	# put HERE and holds the duel open; see the targeted-triggers block.
	if _hold_trigger_targets():
		return
	# THE DAMAGE-PREVENTION WINDOW (§6.8) sits exactly here, because
	# `Duel.hlp` puts it at the same moment: damage has been dealt and
	# nobody has had priority since. A no-op unless the fork is on and a
	# seat asked for the window.
	_maybe_open_damage_window()
	priority_player = active_player
	_passes = 0
	_emit_state()


## Advance to the next step; runs turn-based actions and grants priority
## (or auto-advances for steps that have none — untap, cleanup).
func _advance_step() -> void:
	_rec_turn()   # the search journal, if one is running (see TURN_FIELDS)
	# Mana pools empty at the end of each STEP (CR 500.4) — or, under the
	# 1997 ruleset, at the end of each PHASE, combat counting as one phase
	# that empties only when it is over (RulesOptions.pool_empties_on_attack;
	# the owner's ruling, 2026-08-31). MANA BURN, when switched on, is
	# charged on whichever boundary applies.
	if _pool_empties_now():
		for p in players:
			if rules.mana_burn:
				var burned := p.mana_pool.total()
				if burned > 0:
					# LIFE LOSS, not damage: prevention shields and Ali
					# from Cairo's floor do not apply to it. Written here
					# rather than through adjust_life for exactly that
					# reason, so it journals itself.
					_rec(p, &"life")
					p.life -= burned
					log_line("Mana Burn! %s loses %d life (life %d)" % [
						p.player_name, burned, p.life])
			p.mana_pool.clear()
	# The 1997 ruleset checks for a dead player at PHASE boundaries; the
	# modern one has already done it continuously as a state-based action.
	#
	# AFTER THE BURN, NOT BEFORE, and the order is load-bearing under the
	# full 1997 preset (2026-09-02 audit): both rules fire on the SAME
	# boundary — the pool empties and burns there (manual p.176), the
	# lethal check runs there (p.174) — so checking first handed a player
	# burned below 0 a whole free phase at negative life. The manual's own
	# escape clause ("if you manage to gain back enough life ... before the
	# end of the phase") cannot rescue a mana burn either way, because the
	# burn IS the end of the phase. Each fork was right on its own; only
	# the two together were wrong, which is why no single-fork test saw it.
	if rules.life_checked_at_phase_end and _phase_ends_now():
		_check_lethal_life()
		if game_over:
			return
	# "Until the end of your next upkeep" (Halfdane) ends as the upkeep
	# step ends (CR 611.2b) — the effects created before this turn only.
	if Mtg.STEP_ORDER[_step_index] == Mtg.Step.UPKEEP \
			and continuous.expire_end_of_upkeep_of(active_player, turn_number):
		recalculate()   # only when something actually ended
	# Leaving the end-of-combat step = the combat phase is over: "until
	# end of combat" effects expire NOW, not at cleanup (CR 700.5 — a
	# Jade Statue is a plain artifact again in the second main phase).
	if Mtg.STEP_ORDER[_step_index] == Mtg.Step.COMBAT_END:
		continuous.expire_end_of_combat()
		attacks_without_tapping.clear()   # Johan's offer is per-combat
		# "Attacking"/"blocking" status ends with the combat PHASE, not at
		# the start of its last step (CR 506.4/511.3) — Desert's
		# end-of-combat ping must still find a legal attacking target.
		combat.clear()
		recalculate()
	# Skip blockers/damage when no attackers were declared.
	var next_index := _step_index + 1
	if Mtg.STEP_ORDER[_step_index] == Mtg.Step.DECLARE_ATTACKERS \
			and combat.attackers.is_empty():
		while Mtg.STEP_ORDER[next_index] != Mtg.Step.COMBAT_END:
			next_index += 1
	# CR 510.5: there IS no first-strike damage step unless someone in
	# combat has first strike.
	if Mtg.STEP_ORDER[next_index] == Mtg.Step.FIRST_STRIKE_DAMAGE \
			and not _has_first_strike_damage():
		next_index += 1
	if next_index >= Mtg.STEP_ORDER.size():
		_end_turn()
		return
	_enter_step(next_index)


## The 1997 lethal-life check, run at a PHASE boundary rather than
## continuously (manual p.174: *"If a player has less than 1 life at the
## end of a phase... that player loses the duel. You can go below 0 life
## and not lose if you manage to gain back enough life to put you above 0
## before the end of the phase."*). Only reached when
## RulesOptions.life_checked_at_phase_end is on; poison is unaffected and
## still kills immediately through the normal state-based actions, which
## is what p.177 requires.
##
## Both players dying on the same boundary is a DRAW (manual p.168), not a
## race won by seat order.
func _check_lethal_life() -> void:
	if game_over:
		return
	var doomed: Array[int] = []
	for p in players:
		if p.life <= 0 and not p.has_lost and not p.cant_lose_to_life:
			doomed.append(p.id)
	if doomed.is_empty():
		return
	if doomed.size() >= players.size():
		# CR 104.4b — and this used to say the word "draw" in the log while
		# _lose handed the win to the other seat.
		draw_game("both duelists are at 0 or less life at the end of the phase")
		return
	_lose(doomed[0], "life total is 0 or less at the end of the phase")


## Does the boundary we are crossing right now empty the mana pools?
##
## Modern rules: every step boundary (CR 500.4). The 1997 ruleset: every
## PHASE boundary, with combat counting as ONE phase that empties only
## when it is over — the owner's ruling (2026-08-31) resolving the
## manual's p.176 wording. The end of the turn always empties, whichever
## ruleset is in force.
func _pool_empties_now() -> bool:
	return true if not rules.pool_empties_on_attack else _phase_ends_now()


## Is the step we are LEAVING the last one of its phase? (The end of the
## turn counts.) Shared by the two 1997 rules that key off phases rather
## than steps: the mana-pool emptying and the lethal-life check.
func _phase_ends_now() -> bool:
	var next_index := _step_index + 1
	if next_index >= Mtg.STEP_ORDER.size():
		return true        # the turn is ending
	return Mtg.phase_of(Mtg.STEP_ORDER[_step_index]) \
		!= Mtg.phase_of(Mtg.STEP_ORDER[next_index])


## The untap step's turn-based actions (CR 502.2–502.3). True when done;
## FALSE when held open on a question a human seat must answer (the turn
## then waits on [member awaiting_choice], and [method answer_choice]
## re-runs this from the top with the answer parked — see the TURN-BASED
## hold block).
##
## Every decision is collected before anything is mutated, which is what
## makes the re-run safe:
## - "You may choose not to untap this during your untap step" (Old Man
##   of the Sea, Rubinia Soulsinger, Preacher, Tawnos's Coffin …) is the
##   controller's call, asked per tapped permanent in the 1997 game's own
##   two-line form (`@ISLAND_FISH_JASCONIUS`: *"Untap Island Fish."* /
##   *"Don't untap."*), the heuristic being "stay tapped while it is
##   sustaining a leash or a remembered effect".
## - Under an untap CAP (Smoke: *"players can't untap more than one
##   creature during their untap steps"*, Winter Orb's land, Damping
##   Field's artifact) WHICH permanent untaps is the controller's choice
##   too — *"PROCESSING Smoke: Select creature to untap."* — and a
##   permanent of two capped kinds (an artifact creature under both Smoke
##   and Damping Field) counts against both.
## The turn's BEGINNING, before its untap step (CR 502 lists the untap step
## first, but "if you would begin your turn" is an event of its own): the
## one replacement effect the pool has for it is Time Vault's "if you
## would begin your turn while this artifact is tapped, you may skip that
## turn instead. If you do, untap this artifact" (CardData.
## skips_turn_to_untap, CR 614.10). Each tapped one the active player
## controls asks in battlefield order — `@TIME_VAULT`'s two lines, "Play
## this turn." / "Skip this turn to untap." — through the turn-based hold,
## so a human seat is held on it like an untap-step question; the first
## "skip" ends the asking, because a turn once skipped is no longer
## beginning and no further replacement can apply to it (CR 616.1;
## Duel.hlp: "You cannot untap multiple Time Vaults by skipping the same
## turn"). The heuristic's answer is the 1997 one: skip one turn in five
## (`card_time_vault`, 0x420280 — decompiled), rolled on game.rng so a
## seeded duel repeats it. A Titania's Song has silenced the clause.
##
## Returns TRUE when the turn goes on into its untap step; FALSE when HELD
## on a question (answer_choice re-runs this from the top), or when the
## turn was skipped whole and the next one has been entered.
func _begin_turn() -> bool:
	_begin_cost_choices()
	var pid := active_player
	for inst in players[pid].battlefield:
		if not inst.data.skips_turn_to_untap or not inst.tapped \
				or inst.cur_abilities_silenced:
			continue
		var name := inst.data.card_name
		var labels: Array[String] = ["Play this turn.", "Skip this turn to untap."]
		var q := _turn_question(pid, name, PlayerChoice.Kind.OPTION,
			"Skip this turn to untap %s?" % name)
		q.options = labels
		if _hold_cost_choice(q, {"kind": "begin_turn"}):
			return false
		# The heuristic's one-in-five is rolled only once the seat is NOT
		# held: a held human seat re-runs this from the top on every
		# answer, and a roll above the hold moved game.rng once per re-run
		# — a seeded duel would then roll a different stream depending on
		# whether a human sat here (CONTRIBUTING.md rule 7; 2026-09-02).
		var hint := 1 if rng.randi() % 5 == 0 else 0
		q.hint = hint
		if _ask_turn_option(pid, name, labels, q.prompt, hint) != 1:
			continue
		untap_permanent(inst)
		_skip_turn()
		return false
	_release_hand_locks(pid)   # "until your next turn" — it is here
	return true


## Skip the turn that was about to begin: proceed past it as though it did
## not exist (CR 500.9) — no untap step, no upkeep, no draw, no cleanup,
## and no turn's-end bookkeeping either, since the player's "last turn"
## (Arboria) is still the one they actually took. The turn after it
## follows as it would have (an extra turn queued behind it is next).
func _skip_turn() -> void:
	log_line("%s skips the turn" % players[active_player].player_name)
	_next_turn()


func _untap_step() -> bool:
	_begin_cost_choices()
	var pid := active_player
	var mine := players[pid].battlefield
	# ---- 1. classify, mutating nothing --------------------------------
	var eligible: Array[CardInstance] = []   # untaps unless a cap says no
	var may_stay: Array[CardInstance] = []   # tapped, "may choose not to"
	for inst in mine:
		if inst.skip_next_untap or inst.skip_untaps > 0:
			continue   # Barl's Cage one-shots, Telekinesis-style locks
		if int(inst.counters.get("glyph", 0)) > 0:
			continue   # "doesn't untap while it has a glyph counter"
			           # (Glyph of Delusion; the counters tick down at its
			           # controller's upkeep)
		if inst.cur_skips_untap:
			continue   # Meekstone-style locks
		if inst.data.may_skip_untap and inst.tapped:
			may_stay.append(inst)
		else:
			eligible.append(inst)
	# ---- 2. the questions (each may hold the step) --------------------
	for inst in may_stay:
		var name := inst.data.card_name
		var labels: Array[String] = ["Untap %s." % name, "Don't untap."]
		var hint := 0 if not _is_sustaining(inst) else 1
		var q := _turn_question(pid, name, PlayerChoice.Kind.OPTION,
			"Untap %s?" % name)
		q.options = labels
		q.hint = hint
		if _hold_cost_choice(q, {"kind": "untap"}):
			return false
		if _ask_turn_option(pid, name, labels, q.prompt, hint) == 0:
			eligible.append(inst)
	var untapping: Array[CardInstance] = []
	var chosen_of := {}   # capped kind -> how many chosen to untap
	var capped: Array[CardInstance] = []
	for inst in eligible:
		var under_cap := false
		for kind in _untap_kinds(inst):
			if int(untap_caps.get(kind, -1)) >= 0:
				under_cap = true
		if under_cap and inst.tapped:
			capped.append(inst)
		else:
			untapping.append(inst)
	for kind in ["creature", "land", "artifact"]:
		var cap: int = int(untap_caps.get(kind, -1))
		if cap < 0:
			continue
		var lock := String(untap_cap_sources.get(kind, ""))
		while int(chosen_of.get(kind, 0)) < cap:
			var candidates: Array[CardInstance] = []
			for inst in capped:
				if untapping.has(inst) or not _untap_kinds(inst).has(kind):
					continue
				var room := true
				for other in _untap_kinds(inst):
					var other_cap: int = int(untap_caps.get(other, -1))
					if other_cap >= 0 \
							and int(chosen_of.get(other, 0)) >= other_cap:
						room = false
				if room:
					candidates.append(inst)
			if candidates.is_empty():
				break
			var prompt := "Select %s to untap." % kind
			var pick_q := _turn_question(pid, lock, PlayerChoice.Kind.CARD,
				prompt)
			pick_q.candidates = candidates
			if _hold_cost_choice(pick_q, {"kind": "untap"}):
				return false
			var pick := _ask_turn_card(pid, lock, candidates, prompt)
			untapping.append(pick)
			for other in _untap_kinds(pick):
				if int(untap_caps.get(other, -1)) >= 0:
					chosen_of[other] = int(chosen_of.get(other, 0)) + 1
	# ---- 3. commit ----------------------------------------------------
	var just_untapped: Array[CardInstance] = []
	if undo_log != null:
		# The sweep writes seven fields on every permanent on the table —
		# both seats', because "attacked this turn" is per-TURN state that
		# expires for everyone (below).
		for inst in all_battlefield():
			for field in UNTAP_INSTANCE_FIELDS:
				undo_log.record(inst, field, inst.get(field))
	for inst in mine:
		if inst.skip_next_untap:       # Barl's Cage one-shots
			inst.skip_next_untap = false
		elif inst.skip_untaps > 0:     # Telekinesis-style multi-turn locks
			inst.skip_untaps -= 1
		if untapping.has(inst):
			if inst.tapped:
				just_untapped.append(inst)
			if undo_log != null: _rec(inst, &"tapped")
			inst.tapped = false
		inst.summoning_sick = false
		# Wall of Dust bans: "next turn" becomes "this turn" now,
		# and last turn's ban expires.
		inst.cant_attack_this_turn = inst.cant_attack_next_turn
		inst.cant_attack_next_turn = false
	# "Attacked this turn" is per-TURN state and must expire for every
	# permanent, not just the active player's — Berserk's delayed
	# destruction, Clockwork Beast's wind-down and Lurker's shroud all
	# read it about the OTHER player's creatures. Cleared here rather
	# than at cleanup because Goblin Rock Sled reads it at the end step.
	for inst in all_battlefield():
		inst.attacked_this_turn = false
		inst.could_attack_this_turn = false
	players[pid].lands_played_this_turn = 0
	# Power Surge counts what is untapped as the turn BEGINS.
	var standing := 0
	for inst in mine:
		if inst.is_land() and not inst.tapped:
			standing += 1
	players[pid].untapped_lands_at_turn_start = standing
	recalculate()   # untapping re-enables Castle-style statics
	for woken in just_untapped:
		dispatch_event(Mtg.EventType.BECAME_UNTAPPED,
			{"instance": woken, "controller": woken.controller_id})
	return true


func _enter_step(index: int) -> void:
	_rec_turn()   # the search journal, if one is running (see TURN_FIELDS)
	_step_index = index
	var step := current_step()
	# "The first card they draw in each of their draw steps" counts per
	# STEP, so the counter resets on every boundary (CR 614 context).
	for seat in players:
		seat.draws_this_step = 0
	match step:
		Mtg.Step.UNTAP:
			# The turn BEGINS before its first step, and one replacement
			# effect can apply to that — "if you would begin your turn
			# while this artifact is tapped, you may skip that turn
			# instead" (Time Vault, CR 614.10). Held on its question, or
			# the turn was skipped whole and the next one has already
			# begun: either way nothing more happens here.
			if not _begin_turn():
				return
			# Turn-based actions (CR 502): untap everything, clear sickness
			# and per-turn combat bookkeeping — unless the step is HELD on
			# one of its questions, in which case answer_choice re-runs it.
			if _untap_step():
				_advance_step()   # no priority in untap (CR 502.4)
		Mtg.Step.UPKEEP:
			# "Until your next upkeep" ends HERE (CR 611.2b) — before the
			# glyph tick and before any upkeep trigger goes on the stack,
			# so an artifact Xenic Poltergeist animated last turn is a
			# plain artifact again by the time anything can look at it.
			continuous.expire_upkeep_of(active_player)
			recalculate()
			check_state_based_actions()
			# "At the beginning of your upkeep, remove a glyph counter from
			# this creature" (Glyph of Delusion). A turn-based tick, so it
			# needs no permanent to carry the granted ability.
			for inst in players[active_player].battlefield:
				var glyphs: int = int(inst.counters.get("glyph", 0))
				if glyphs <= 0:
					continue
				if glyphs == 1:
					inst.counters.erase("glyph")
				else:
					inst.counters["glyph"] = glyphs - 1
				log_line("%s loses a glyph counter" % inst.data.card_name)
			dispatch_event(Mtg.EventType.UPKEEP_START, {"player": active_player})
			_open_priority()
		Mtg.Step.DRAW:
			# "If you would begin your draw step, you may skip that step
			# instead" (Fasting) — CR 614 applied to a turn-based action.
			# A skipped step happens not at all: no draw, no DRAW_STEP
			# event, no priority in it.
			if _draw_step_skipped(active_player):
				log_line("%s skips their draw step"
					% players[active_player].player_name)
				_advance_step()
				return
			if _skip_first_draw and turn_number == 1:
				log_line("%s skips the first draw" % players[active_player].player_name)
			else:
				draw_cards(active_player, 1)
			if game_over:
				return
			# Howling Mine et al. hook in here, after the normal draw.
			dispatch_event(Mtg.EventType.DRAW_STEP, {"player": active_player})
			_open_priority()
		Mtg.Step.COMBAT_BEGIN:
			# "At the beginning of combat on your turn ..." (Battering Ram,
			# Johan). Dispatched before attackers are declared, which is the
			# window both cards need.
			dispatch_event(Mtg.EventType.COMBAT_START, {"player": active_player})
			_open_priority()
		Mtg.Step.DECLARE_ATTACKERS:
			combat.clear()
			_first_strike_ids.clear()
			awaiting_attackers = true
			_emit_state()
		Mtg.Step.DECLARE_BLOCKERS:
			awaiting_blockers = true
			_emit_state()
		Mtg.Step.FIRST_STRIKE_DAMAGE:
			# _combat_damage_step hands out priority itself when its damage
			# has landed — it may pause first, waiting on a division.
			_combat_damage_step(true)
		Mtg.Step.COMBAT_DAMAGE:
			_combat_damage_step(false)
		Mtg.Step.COMBAT_END:
			# The basilisk gaze: condemned creatures die now (CR 511-era
			# "at end of combat"), before combat state clears.
			for doomed_id in _end_of_combat_doom:
				var doomed := find_instance(doomed_id)
				if doomed != null and doomed.zone == Mtg.Zone.BATTLEFIELD:
					destroy(doomed, true)
			_end_of_combat_doom.clear()
			# Delayed end-of-combat ACTIONS (Glyph of Doom). Taken as a
			# snapshot so an action that schedules another does not loop.
			var pending := _end_of_combat_actions.duplicate()
			_end_of_combat_actions.clear()
			for action in pending:
				action.call(self)
			recalculate()
			dispatch_event(Mtg.EventType.END_OF_COMBAT, {"player": active_player})
			_open_priority()
		Mtg.Step.END:
			# Delayed "destroy it at the beginning of the next end step"
			# (Berserk, Stone Giant, Glyph of Destruction).
			for doomed_id in _end_step_doom:
				var doomed := find_instance(doomed_id)
				if doomed == null or doomed.zone != Mtg.Zone.BATTLEFIELD:
					continue
				# Berserk's intervening "if it attacked this turn" is
				# checked HERE, when the delayed trigger goes off.
				if _end_step_doom_if_attacked.has(doomed_id) \
						and not doomed.attacked_this_turn:
					continue
				if _end_step_doom_unless_attacked.has(doomed_id) \
						and doomed.attacked_this_turn:
					continue
				if _end_step_doom_sacrifice.has(doomed_id):
					sacrifice_permanent(doomed)   # "sacrifice", not "destroy"
				else:
					destroy(doomed, true)
			_end_step_doom.clear()
			_end_step_doom_sacrifice.clear()
			_end_step_doom_if_attacked.clear()
			_end_step_doom_unless_attacked.clear()
			# Delayed token creation (Rukh Egg).
			var pending := _end_step_tokens.duplicate()
			_end_step_tokens.clear()
			for entry in pending:
				create_token(int(entry["controller"]), entry["data"])
			# Delayed end-step ACTIONS that outlive their source (Rakalite).
			var end_actions := _end_step_actions.duplicate()
			_end_step_actions.clear()
			for action in end_actions:
				action.call()
			dispatch_event(Mtg.EventType.END_STEP_START, {"player": active_player})
			_open_priority()
		Mtg.Step.CLEANUP:
			_cleanup_step()
		Mtg.Step.MAIN1, Mtg.Step.MAIN2:
			# "At the beginning of your next main phase ..." (Mana Drain).
			var due: Array[Dictionary] = []
			var still: Array[Dictionary] = []
			for entry in _next_main_actions:
				if int(entry["player"]) == active_player:
					due.append(entry)
				else:
					still.append(entry)
			_next_main_actions = still
			for entry in due:
				entry["action"].call()
			_open_priority()
		_:
			_open_priority()


## ONE combat damage STEP. Combat damage is dealt in two steps when anyone
## in combat has first strike (CR 510.4/510.5) — and the two are separated
## by a full priority round, which is when you finish off the survivor or
## pump the creature that has yet to strike. The 1997 game drew them as two
## Combat Bar icons, "Resolve 1st strike damage" and "Resolve normal
## damage" (`@CUECARD_PHASEBAR`), so this is its shape as well as the CR's.
##
## [param first_strike_wave] says which step this is; membership is frozen
## when the FIRST one begins (see [member _first_strike_ids]).
func _combat_damage_step(first_strike_wave: bool) -> void:
	if combat_damage_prevented:
		# Fog is checked per step: one cast in the first-strike window still
		# stops the normal wave, which is exactly what the window is for.
		log_line("All combat damage is prevented this turn (Fog)")
		_after_combat_damage()
		return
	if first_strike_wave:
		# CR 510.4: the SECOND damage step is for "the remaining attackers
		# and blockers that had neither first strike nor double strike as
		# the first combat damage step began" — membership is decided once,
		# here, not re-read per wave. Otherwise a creature that loses first
		# strike between the steps (its granting lord died in the first)
		# strikes twice.
		_first_strike_ids = {}
		for inst in all_battlefield():
			if inst.has_keyword(Mtg.Keyword.FIRST_STRIKE):
				_first_strike_ids[inst.id] = true
	# THE DIVISIONS (docs/duel-todo.md §1.4): every packet this step will
	# deal is planned first, then each assigner answers for its own, then
	# they all land together.
	_damage_requests = _collect_damage_requests(first_strike_wave)
	_damage_splits = []
	_damage_splits.resize(_damage_requests.size())
	_damage_cursor = 0
	_wave_assigned = {}
	_resume_damage_assignment()


## Is there a first-strike damage step this combat? CR 510.5: only when at
## least one attacking or blocking creature has first strike as the
## declare-blockers step ends. [method _advance_step] skips the step
## outright otherwise, so a combat without first strikers stops for damage
## exactly once, as it always did.
func _has_first_strike_damage() -> bool:
	for id in combat.attackers:
		var attacker := find_instance(id)
		if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD \
				and attacker.has_keyword(Mtg.Keyword.FIRST_STRIKE):
			return true
	for id in combat.blocks:
		var blocker := find_instance(id)
		if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD \
				and blocker.has_keyword(Mtg.Keyword.FIRST_STRIKE):
			return true
	return false


## THE DAMAGE REQUESTS of one combat damage step: one entry per creature
## that deals damage in this step, in the order the packets will be built.
## Each is
## `{source, targets (ids, in assignment order), amount, trample, blocked,
##   spill_to_last, assigner, defender}`.
## Collected BEFORE anything is dealt, because combat damage in a step is
## simultaneous (CR 510.4) and because a seat that assigns its own damage
## has to be shown every division before any of them lands.
func _collect_damage_requests(first_strike_wave: bool) -> Array:
	var defender := opponent_of(active_player)
	var out: Array = []
	# blocker id -> every attacker it is fighting, across every band it
	# blocks into; and the blockers in the order they were first seen, so
	# the request list stays deterministic. See the blocker side below.
	var blocker_targets := {}
	var blocker_order: Array[CardInstance] = []
	for band in combat.all_bands():
		# Live band members and live blockers committed against the band.
		var members: Array[CardInstance] = []
		for id in band:
			var m := find_instance(id)
			if m != null and m.zone == Mtg.Zone.BATTLEFIELD:
				members.append(m)
		if members.is_empty():
			continue
		var was_blocked := combat.was_blocked(band)
		var blockers: Array[CardInstance] = []
		# CR 509.2: the attacking player's announced order, not the
		# defender's declaration order (CombatState.damage_order).
		for blocker_id in combat.ordered_blockers_of_band(band):
			var b := find_instance(blocker_id)
			if b != null and b.zone == Mtg.Zone.BATTLEFIELD:
				blockers.append(b)
		var blocker_ids: Array = []
		for b2 in blockers:
			blocker_ids.append(b2.id)
		var member_ids: Array = []
		for m2 in members:
			member_ids.append(m2.id)
		# DEFENSIVE BANDING (CR 702.22j): if ANY creature blocking this
		# band has banding — or "both a [quality] creature with 'bands
		# with other [quality]' and another [quality] creature" are among
		# the blockers (the Legends banding lands) — the DEFENDING player
		# divides each attacker's combat damage among its blockers, and
		# does it FREELY — the lethal-first order of CR 510.1c does not
		# apply. That is the whole point of blocking with a Benalish Hero:
		# the damage goes where the defender wants it, not where it kills
		# most.
		var banded_block := CombatState.bands_with_among(blockers)
		for b3 in blockers:
			if b3.has_keyword(Mtg.Keyword.BANDING):
				banded_block = true
				break

		# --- attacker side ---
		for member in members:
			if _first_strike_ids.has(member.id) != first_strike_wave:
				continue
			out.append({
				"source": member,
				"targets": [] if not was_blocked else blocker_ids.duplicate(),
				"amount": member.cur_power,
				"trample": was_blocked and member.has_keyword(Mtg.Keyword.TRAMPLE),
				"blocked": was_blocked,
				"spill_to_last": false,
				"assigner": defender if banded_block else member.controller_id,
				"free_order": banded_block,
				"defender": defender,
			})

		# --- blocker side ---
		# COLLECTED, NOT EMITTED, because a blocker may be in more than one
		# band (CR 509.1b — Two-Headed Giant of Foriys blocks two attackers,
		# which can be two different bands). Emitting inside this loop gave
		# it one request per band and had it deal its full power twice.
		for blocker in blockers:
			if _first_strike_ids.has(blocker.id) != first_strike_wave:
				continue
			if not blocker_targets.has(blocker.id):
				blocker_targets[blocker.id] = []
				blocker_order.append(blocker)
			var reach: Array = blocker_targets[blocker.id]
			for id in member_ids:
				if not reach.has(id):
					reach.append(id)
	for blocker in blocker_order:
		out.append({
			"source": blocker,
			"targets": (blocker_targets[blocker.id] as Array).duplicate(),
			"amount": blocker.cur_power,
			"trample": false,
			"blocked": true,
			# A single-target blocker must deal its damage as ONE packet
			# (Jade Monolith's redirection soaks a whole packet, not a
			# lethal-sized sliver), and a band's leftover joins the last
			# member (CR 510.1d) — both are this flag.
			"spill_to_last": true,
			"assigner": blocker.controller_id,
			"free_order": false,
			"defender": defender,
		})
	return out


## The engine's own lethal-first division — the heuristic that used to be
## the only answer, now the DecisionAgent's documented default and the
## backstop for any answer the engine judges illegal.
##
## Walks [param targets] in assignment order, giving each exactly its
## remaining lethal until the damage runs out; [param already] is what this
## step has assigned so far, so two 2/2s gang-blocking a 3/3 split 2+1 and
## not 2+2. A [param trample] surplus goes to the defending player
## (CR 702.19b); without trample it is simply dropped (CR 510.1c-d).
## [param free_order] is the defensive-banding division (CR 702.22f-h),
## which the DEFENDING player makes: lethal-first is exactly the wrong
## default there — it would kill as many of their own blockers as the
## damage can reach — so the whole amount goes onto the ONE body they mind
## losing least, and every other blocker walks away. Piling it on a single
## creature also denies a trampling attacker its spill-over, which is the
## printed interaction and the reason to band-block a trampler at all.
func default_damage_split(_source: CardInstance, targets: Array, amount: int,
		trample: bool, already: Dictionary, free_order := false) -> Dictionary:
	if free_order and amount > 0:
		var cheapest: CardInstance = null
		for id in targets:
			var blocker := find_instance(int(id))
			if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD:
				continue
			if cheapest == null or _defensive_value(blocker) \
					< _defensive_value(cheapest):
				cheapest = blocker
		if cheapest != null:
			return {cheapest.id: amount}
	var out: Dictionary = {}
	var left := amount
	for id in targets:
		if left <= 0:
			break
		var t := find_instance(int(id))
		if t == null or t.zone != Mtg.Zone.BATTLEFIELD:
			continue
		var lethal: int = maxi(
			t.cur_toughness - t.damage - int(already.get(t.id, 0)), 0)
		if lethal <= 0:
			continue
		var chunk: int = mini(left, lethal)
		out[t.id] = int(out.get(t.id, 0)) + chunk
		left -= chunk
	if left > 0 and trample:
		out[DAMAGE_TO_PLAYER] = left
	return out


## What a blocker is worth to the player who has to choose which of their
## own creatures eats a banded attacker's damage. Cheap and honest: body
## size first, mana value to break the tie.
func _defensive_value(inst: CardInstance) -> int:
	return (inst.cur_power + inst.cur_toughness) * 100 \
		+ inst.data.cost.mana_value()


## How much more damage would bury [param inst] right now, counting damage
## already marked on it and everything assigned to it this damage step.
func lethal_remaining(inst: CardInstance, already: Dictionary) -> int:
	return maxi(inst.cur_toughness - inst.damage - int(already.get(inst.id, 0)), 0)


## Does [param request] present a real DIVISION for its assigner to make?
## Two or more blockers, or trample (how much spills over is a choice on
## its own). A single blocker with no trample has exactly one legal answer.
func _request_is_a_choice(request: Dictionary) -> bool:
	if int(request["amount"]) <= 0:
		return false
	var targets: Array = request["targets"]
	if bool(request["spill_to_last"]):
		return targets.size() >= 2
	return targets.size() >= 2 or (bool(request["trample"]) and targets.size() >= 1)


## Validate one split against its request. "" when legal, else the refusal
## the player reads — the 1997 counter ("%d points left") included.
func _split_illegality(request: Dictionary, split: Dictionary) -> String:
	var targets: Array = request["targets"]
	var amount := int(request["amount"])
	var trample := bool(request["trample"])
	var spill := bool(request["spill_to_last"])
	var total := 0
	for key in split:
		var points := int(split[key])
		if points < 0:
			return "damage can't be negative"
		if key == DAMAGE_TO_PLAYER:
			if not trample:
				return "only a trampling attacker may assign damage to the player"
		elif not targets.has(int(key)):
			var stray := find_instance(int(key))
			return "%s is not blocking %s" % [
				stray.data.card_name if stray != null else "#%d" % int(key),
				request["source"].data.card_name]
		total += points
	if total > amount:
		return "%s has only %d points to assign" % [
			request["source"].data.card_name, amount]
	# CR 510.1c: lethal to each blocker before the next one in the order.
	# The 1997 ruleset had no order at all — RulesOptions.free_damage_assignment.
	var all_lethal := true
	for id in targets:
		var inst := find_instance(int(id))
		if inst == null:
			continue
		var points2 := int(split.get(int(id), 0))
		var need := lethal_remaining(inst, _wave_assigned)
		if points2 > 0 and not all_lethal \
				and not rules.free_damage_assignment and not spill \
				and not bool(request.get("free_order", false)):
			return "assign lethal damage to the earlier blockers before %s" \
				% inst.data.card_name
		if points2 < need:
			all_lethal = false
	if int(split.get(DAMAGE_TO_PLAYER, 0)) > 0 and not all_lethal:
		# True under BOTH rulesets: the original made trample its own second
		# prompt, after the blockers had been dealt with (CR 702.19b).
		return "every blocker needs lethal damage before any tramples through"
	if total < amount and not spill:
		if trample or not all_lethal:
			return "%s: assign damage to blockers, %d points left" % [
				request["source"].data.card_name, amount - total]
	return ""


## The step's current unanswered division, for the UI:
## `{source, targets, amount, trample, assigner, assigned}` — `assigned` is
## what the step has already put on each creature, which is what the
## "points left" counter and the lethal marks are computed from.
## Empty when [member awaiting_damage_assignment] is false.
func damage_assignment_request() -> Dictionary:
	if not awaiting_damage_assignment \
			or _damage_cursor >= _damage_requests.size():
		return {}
	var request: Dictionary = _damage_requests[_damage_cursor].duplicate()
	request["assigned"] = _wave_assigned.duplicate()
	return request


## Answer the division the damage step is waiting on. [param split] maps a
## blocker (or attacker) instance id to points, plus the optional
## [constant DAMAGE_TO_PLAYER] key for trample. "" on success, else a
## refusal — the step stays open either way until a legal split arrives.
func assign_combat_damage(pid: int, split: Dictionary) -> String:
	if game_over:
		return "the game is over"
	if not awaiting_damage_assignment:
		return "no combat damage is waiting to be assigned"
	var request: Dictionary = _damage_requests[_damage_cursor]
	if pid != int(request["assigner"]):
		return "%s's damage is not yours to assign" % request["source"].data.card_name
	var why := _split_illegality(request, split)
	if why != "":
		return why
	awaiting_damage_assignment = false
	_commit_split(split)
	_resume_damage_assignment()
	return ""


## Record one answered division and move the cursor on, adding it to the
## step's running total so the next division's "lethal" accounts for it.
func _commit_split(split: Dictionary) -> void:
	var request: Dictionary = _damage_requests[_damage_cursor]
	var final := split.duplicate()
	if bool(request["spill_to_last"]):
		# CR 510.1d: a blocker's leftover power has to land somewhere — it
		# joins the last creature it is facing.
		var total := 0
		for key in final:
			total += int(final[key])
		var targets: Array = request["targets"]
		if total < int(request["amount"]) and not targets.is_empty():
			var last := int(targets[-1])
			final[last] = int(final.get(last, 0)) + int(request["amount"]) - total
	for key in final:
		if key == DAMAGE_TO_PLAYER:
			continue
		_wave_assigned[int(key)] = int(_wave_assigned.get(int(key), 0)) \
			+ int(final[key])
	_damage_splits[_damage_cursor] = final
	_damage_cursor += 1


## Walk the step's divisions, asking each assigner in turn. A seat that
## wants to choose for itself (the human) stops the walk here; everyone
## else answers through their DecisionAgent and the step runs straight
## through, exactly as it always did.
func _resume_damage_assignment() -> void:
	while _damage_cursor < _damage_requests.size():
		var request: Dictionary = _damage_requests[_damage_cursor]
		var assigner := int(request["assigner"])
		if _request_is_a_choice(request) \
				and agents[assigner].wants_to_assign_combat_damage():
			awaiting_damage_assignment = true
			# `@PROMPT_RESOLVECOMBAT` entry 1, Program/UIStrings.txt:999.
			log_line("%s: Assign damage to blockers, %d points left" % [
				request["source"].data.card_name, int(request["amount"])])
			_emit_state()
			return
		_commit_split(_agent_split(request))
	_apply_damage_requests()
	_after_combat_damage()


## One seat's answer for one division, validated. An illegal answer is
## replaced by [method default_damage_split] rather than refused: an agent
## is engine code, and a duel must not stall on a bad one.
func _agent_split(request: Dictionary) -> Dictionary:
	if not bool(request["blocked"]):
		return {}   # unblocked: the whole amount goes to the player
	var targets: Array = request["targets"]
	var amount := int(request["amount"])
	var trample := bool(request["trample"])
	var source: CardInstance = request["source"]
	if amount <= 0:
		return {}
	var free_order := bool(request.get("free_order", false))
	var split: Dictionary = agents[int(request["assigner"])].assign_combat_damage(
		self, source, targets, amount, trample, _wave_assigned, free_order)
	if _split_illegality(request, split) != "":
		return default_damage_split(source, targets, amount, trample,
			_wave_assigned, free_order)
	return split


## Deal every division of this step at once. CR 510.4 / 704.3: all combat
## damage in a step is dealt SIMULTANEOUSLY, and state-based actions are
## performed afterwards as a single event. Checking them between packets
## would bury a creature before its own damage-dealt trigger is offered
## (El-Hajjâj drinking the damage it deals while dying).
func _apply_damage_requests() -> void:
	var packets: Array = []
	for i in _damage_requests.size():
		var request: Dictionary = _damage_requests[i]
		var source: CardInstance = request["source"]
		var defender := int(request["defender"])
		if not bool(request["blocked"]):
			# CR 509.1h: only an UNBLOCKED attacker hits the player directly.
			packets.append([source, TargetRef.player(defender),
				int(request["amount"])])
			continue
		var split: Dictionary = _damage_splits[i]
		if split == null:
			continue
		for key in split:
			var points := int(split[key])
			if points <= 0:
				continue
			if key == DAMAGE_TO_PLAYER:
				packets.append([source, TargetRef.player(defender), points])
				continue
			var victim := find_instance(int(key))
			if victim != null:
				packets.append([source, TargetRef.card(victim), points])
	_damage_requests = []
	_damage_splits = []
	_damage_cursor = 0
	begin_simultaneous()
	for p in packets:
		deal_damage(p[0], p[1], p[2], true)   # combat damage
	end_simultaneous()


## What the damage step does once its damage has landed: hand priority
## round, so the players can respond before the step ends.
func _after_combat_damage() -> void:
	if game_over:
		return
	_open_priority()


## Cleanup (CR 514): discard to hand size, damage wears off, until-EOT
## effects expire; then the turn passes. The discard is either answered by
## the seat's DecisionAgent or — for a seat that asked to choose, i.e. the
## human — held open as THE DISCARD PHASE until
## [method discard_to_hand_size] arrives (docs/duel-todo.md §1.1).
## SIMPLIFIED: cleanup grants no priority.
func _cleanup_step() -> void:
	_flush_stranded_damage()
	var p := players[active_player]
	var over := p.hand.size() - p.max_hand_size
	if over > 0:
		# THE DISCARD PHASE (§1.1): a seat that wants to choose for itself
		# holds the turn here until discard_to_hand_size answers. The 1997
		# game's own words for this moment are "Paused: Discard phase".
		if agents[active_player].wants_to_choose_discard():
			awaiting_discard = true
			discard_count = over
			log_line("%s must discard %d card%s" % [
				p.player_name, over, "" if over == 1 else "s"])
			_emit_state()
			return
		var chosen := agents[active_player].choose_discard(self, active_player, over)
		discard_cards(active_player, chosen, false)   # CR 514.1: no effect
		# Backstop against a misbehaving agent returning too few.
		while p.hand.size() > p.max_hand_size:
			discard_cards(active_player, [p.hand[-1]], false)
	_finish_cleanup()


## The active player's answer to the discard phase: exactly
## [member discard_count] cards from their own hand. Returns "" on success
## (cleanup then finishes and the turn passes) or a refusal string.
func discard_to_hand_size(pid: int, cards: Array) -> String:
	if game_over:
		return "the game is over"
	if not awaiting_discard:
		return "not the time to discard"
	if pid != active_player:
		return "only the active player discards at cleanup"
	if cards.size() != discard_count:
		# @PROMPT_DISCARDACARD's own verb, with the count the phase wants.
		return "select %d card%s to discard" % [
			discard_count, "" if discard_count == 1 else "s"]
	var seen := {}
	for inst in cards:
		if inst == null or not players[pid].hand.has(inst):
			return "that card is not in your hand"
		if seen.has(inst.id):
			return "you can't discard the same card twice"
		seen[inst.id] = true
	discard_cards(pid, cards, false)   # CR 514.1: a turn-based action
	awaiting_discard = false
	discard_count = 0
	_finish_cleanup()
	return ""


## Everything cleanup does AFTER the discard: damage wears off, the
## until-end-of-turn ledgers empty, and the turn passes (CR 514.2).
func _finish_cleanup() -> void:
	if undo_log != null:
		# CLEANUP writes twenty-six fields per permanent, so the whole
		# object goes down rather than a list that would rot the next time
		# a this-turn flag is added below (`engine/undo_log.gd`,
		# [method UndoLog.record_object]). It is the one boundary whose
		# record is linear in the board, and it is once a turn.
		for inst in all_battlefield():
			undo_log.record_object(inst)
	for inst in all_battlefield():
		inst.damage = 0
		inst.damaged_by_this_turn.clear()
		inst.damage_from_this_turn.clear()
		inst.damaged_players_this_turn.clear()
		inst.blocked_this_turn = false
		inst.blocked_ids_this_turn.clear()   # block history is per-turn
		inst.must_block_this_turn = false
		# The grant that came with the order — Blaze of Glory's "can block
		# any number of creatures THIS TURN" — expires here too (CR 514.2);
		# until 2026-09-02 it did not, and a Wall once conscripted could
		# block the whole team every turn for the rest of the game.
		inst.extra_blocks_this_turn = 0
		inst.must_attack_this_turn = false
		inst.damage_redirect_to = -1
		inst.damage_redirects = 0
		inst.damage_redirect_sources.clear()
		inst.damage_point_redirect_to = -1   # Personal Incarnation's points
		inst.damage_point_redirects = 0
		inst.exile_instead_of_dying = false
		inst.regeneration_shields = 0   # shields last one turn (CR 701.15)
		inst.destruction_shields = 0    # Pyramids' shield is this-turn too
		inst.damage_all_redirect_to = -1   # Reverberation is this-turn only
		inst.regeneration_banned_this_turn = false
		inst.damage_unpreventable_this_turn = false
		inst.prevention = 0             # damage prevention is this-turn only
		inst.ability_uses.clear()       # "N times each turn" counters reset
	for pl in players:
		pl.artifact_damage_this_turn = 0
		pl.damage_taken_this_turn = 0
		pl.reverse_damage_sources.clear()
		pl.prevention_shields.clear()   # CoP shields are this-turn only
		pl.prevention_shield_filters.clear()
		pl.damage_prevention = 0
		pl.damage_replacements.clear()  # "the next time ... this turn"
		pl.may_take_creature_damage = false   # Blood of the Martyr
		pl.drawn_this_turn.clear()      # "cards drawn this turn" (Sylvan Library)
		pl.attacked_this_turn = false   # "who attacked this turn" (Fire and Brimstone)
		pl.life_for_mana = false        # Channel is an until-end-of-turn grant
		pl.paid_prevention.clear()      # Guardian Angel's rider is too
		pl.land_mana_becomes = 0        # Deep Water is until end of turn too
	# "The next time you would draw a card THIS TURN" expires unspent
	# (Aladdin's Lamp).
	_one_shot_draws.clear()
	# "Until end of turn" control changes go home (Disharmony).
	for lease in _control_until_eot:
		var borrowed := find_instance(int(lease["instance_id"]))
		if borrowed != null and borrowed.zone == Mtg.Zone.BATTLEFIELD:
			change_control(borrowed, int(lease["owner_pid"]))
	_control_until_eot.clear()
	camouflage_this_turn = false
	no_attacks_this_turn = false
	life_on_damage_watchers.clear()   # Glyph of Life is a this-turn watch
	death_watchers.clear()            # "when it dies THIS TURN" (Reincarnation)
	damage_watchers.clear()           # Runesword's watch is this-turn only
	damage_dealt_this_turn.clear()
	for pl2 in players:
		pl2.any_color_spells = 0      # North Star's charge is this-turn only
	combat_damage_prevented = false
	creatures_died_this_turn = 0
	spells_cast_this_turn = [[], []]
	continuous.expire_until_eot()
	recalculate()
	_end_turn()


func _end_turn() -> void:
	if game_over:
		return
	# Arboria: roll THIS player's activity into "their last turn" as their
	# turn ends, so every seat carries its own history.
	players[active_player].acted_last_turn = players[active_player].acted_this_turn
	players[active_player].acted_this_turn = false
	_next_turn()


## Hand the game to whoever takes the next turn — a queued extra turn's
## player first (CR 500.7), otherwise the opponent — and begin it. Shared
## by a turn that ended and a turn that was skipped (see [method
## _skip_turn]); the hand locks of "until your next turn" are released as
## the new turn actually begins (see [method _begin_turn]).
func _next_turn() -> void:
	if not extra_turns.is_empty():
		# Time Walk: the queued player takes the next turn (CR 500.7).
		active_player = extra_turns.pop_front()
		log_line("%s takes an extra turn!" % players[active_player].player_name)
	else:
		active_player = opponent_of(active_player)
	turn_number += 1
	_skip_first_draw = false
	log_line("== Turn %d — %s ==" % [turn_number, players[active_player].player_name])
	_enter_step(0)
