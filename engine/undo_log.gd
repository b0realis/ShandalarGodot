class_name UndoLog
extends RefCounted
## A MAKE/UNMAKE JOURNAL for search — the fork [GameSnapshot] is not.
##
## WHY IT EXISTS. `GameSnapshot` is a REWIND: it reads every mutable
## object's script variables out and writes them back, which costs about
## 3.4 ms on a 127-object early board and is LINEAR in the whole game
## rather than in the move. A search does not need the whole game put
## back — it needs the last move put back, and a move changes 1-4 objects
## and 2-10 fields whatever the board size (measured, `tools/bench_undo.gd`
## section D). This records those fields and replays them backwards.
##
## WHAT MAKES IT POSSIBLE. CONTRIBUTING.md rule 2: every state mutation goes
## through an [MtgGame] helper, so the "record the old value" call has ONE
## surface to live on. Nothing outside `engine/mtg_game.gd` records
## anything.
##
## PRIMARY STATE ONLY, and that is the load-bearing simplification. A
## CardInstance has 93 script variables of which 37 are `cur_*` — DERIVED
## characteristics that [method ContinuousEffects.recalculate] rebuilds
## from scratch every time it runs (CR 613: reset to printed, then reapply
## every layer). The same is true of the player-level flags statics write
## (`max_hand_size`, `combat_damage_redirect`, ...) and of the battlefield
## index caches. Journaling those would mean instrumenting the 97 card
## scripts that write them; rebuilding them costs one `recalculate()`,
## which is 20 us on an early board. So [method undo_to] restores primary
## state and the caller recalculates. [method MtgGame.unmake_to] does both.
##
## RNG IS PART OF THE STATE (CONTRIBUTING.md rule 7). A search that draws from
## `game.rng` while exploring and does not put the stream back changes what
## the REAL game rolls, which would break every seeded replay the Deck Lab
## rests on. [method mark] records `rng.state`, so unwinding to a mark
## restores it. `tests/ai/test_undo_log.gd` pins that.
##
## COST, measured on the same workload as the snapshot above: 0.13 us to
## record one field, 0.14 us to write one back.
##
## SHAPE. Three parallel TYPED arrays rather than an array of records or a
## dictionary: a typed array stores its elements unboxed, and an append to
## three of them beats one append of a three-element Array.
##
## WHAT IS COVERED, AND THE BOUNDARY. Pinned by `tests/ai/test_undo_log.gd`
## against [GameSnapshot]'s own definition of "all the mutable state there
## is", move by move:
##
## - every [MtgGame] helper that moves a card between zones, marks damage,
##   changes life, taps, adds counters, pushes onto or pops the stack, or
##   files a delayed action — that is CONTRIBUTING.md rule 2's surface;
## - a permanent LEAVING the battlefield, as a whole object
##   ([method record_object]), by whichever door;
## - the object of a resolving stack item and its targets, as whole
##   objects, plus the per-turn tables card scripts write by hand — taken
##   at the top of [method MtgGame._resolve_top], which is where a card
##   script gets to write anything at all;
## - the floating until-end-of-turn lists in [ContinuousEffects], which
##   card scripts append to directly and which therefore record themselves
##   (see its `journal`);
## - `rng.state`, the probe flag and the mana pools, at every mark;
## - the TURN MACHINERY, since 2026-09-05: `_advance_step`, `_enter_step`,
##   the untap sweep, the draw step, both combat damage steps, the end
##   step, cleanup and the turn boundary itself, through
##   [method MtgGame._rec_turn] and its three field lists. A search node
##   may therefore CROSS a step boundary, which is what the crack-back
##   search needed and could not have (docs/ROADMAP.md, "The journal
##   across a step boundary"). What it costs is the honest half of that
##   entry: ONE boundary is 11-19x cheaper than a [GameSnapshot] of the
##   same board (264 records, 198-527 us against 3.7-6.0 ms;
##   `tools/bench_undo.gd` section I), but a WHOLE TURN is at parity with
##   one — 0.8-1.1x — because the journal is proportional to the move and
##   untap and cleanup between them write every permanent on the table.
##
## NOT covered, and a search must not cross it: a card script that writes
## a primary field onto a THIRD object during resolution — neither its own
## card nor a target (an aura's host, "each creature you control" written
## by hand instead of through a helper) — is outside the journal until
## that write moves onto a helper. Recorded in docs/ROADMAP.md (M4
## phase 3).

var _obj: Array[Object] = []
var _prop: Array[StringName] = []
var _val: Array = []

## Deliberately NO reference to the game itself. `MtgGame.undo_log` points
## here, so a field pointing back would be a reference cycle, and a
## search that finished with `unmake_to` but forgot `end_search` would
## leak the whole game — every instance, both players, the log. The only
## back-references are the records in `_obj`, and [method undo_to] and
## [method clear] release those. (A field of that shape did exist until
## the second review of 2026-09-02; `tests/ai/test_undo_log.gd` was
## leaking 2342 objects a run through it.)


## Note the CURRENT value of [param obj]'s [param prop] so [method undo_to]
## can put it back. Containers are DUPLICATED: an Array or Dictionary read
## out of a property shares its storage with the object, so recording the
## reference would record a value that is about to be mutated in place.
func record(obj: Object, prop: StringName, value: Variant) -> void:
	_obj.append(obj)
	_prop.append(prop)
	var t := typeof(value)
	if t == TYPE_ARRAY:
		# DEEP: `spells_cast_this_turn` is an Array of two Arrays and the
		# append that has to be undone lands on the INNER one, which a
		# shallow duplicate would still share. Objects are never copied by
		# Godot's deep duplicate, so the zone arrays stay identity-preserving.
		_val.append((value as Array).duplicate(true))
	elif t == TYPE_DICTIONARY:
		_val.append((value as Dictionary).duplicate(true))
	elif t >= TYPE_PACKED_BYTE_ARRAY:
		_val.append(value.duplicate())
	else:
		_val.append(value)


## Record EVERY primary field of [param obj] at once — its script variables
## minus the `cur_*` ones [method ContinuousEffects.recalculate] rebuilds.
##
## For the moments a helper rewrites an object wholesale rather than a
## field at a time: a permanent leaving the battlefield has ~45 fields
## wiped by [method CardInstance.clear_battlefield_state] and its `data`
## swapped back by `restore_printed_identity`; a resolving effect may write
## anything onto its own card and its targets (card scripts set `memory`,
## `prevention`, the regeneration shields ... directly, outside the
## helpers — see THE BOUNDARY below). One record per field, so the cost
## stays proportional to the move; the field list is cached per script.
func record_object(obj: Object) -> void:
	var script: Script = obj.get_script()
	var key := script.get_instance_id()
	var names: Array = _primary_props.get(key, [])
	if names.is_empty():
		for p in obj.get_property_list():
			if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var pname: StringName = p["name"]
			if not String(pname).begins_with("cur_"):
				names.append(pname)
		_primary_props[key] = names
	for pname in names:
		record(obj, pname, obj.get(pname))


## Primary (non-`cur_*`) script variable names per script instance id —
## filled by the first [method record_object] on each class.
static var _primary_props: Dictionary = {}


## Open a node: returns the mark to hand back to [method undo_to].
## Records `rng.state` so exploring cannot consume the real game's stream.
func mark(game: MtgGame) -> int:
	record(game.rng, &"state", game.rng.state)
	return _obj.size() - 1


## Unmake everything recorded since [param mark], newest first, and forget
## it. Replaying BACKWARDS is what makes duplicate records harmless: if a
## field was written twice the older value is written last and wins.
##
## Derived state is NOT restored here — see the class doc. Callers that
## need `cur_*` back call [method MtgGame.recalculate]; [method
## MtgGame.unmake_to] is the one that does both.
func undo_to(mark_index: int) -> void:
	var i := _obj.size() - 1
	while i >= mark_index:
		_obj[i].set(_prop[i], _val[i])
		i -= 1
	if mark_index < 0:
		mark_index = 0
	_obj.resize(mark_index)
	_prop.resize(mark_index)
	_val.resize(mark_index)


## How many field records are outstanding — for tests and for sizing.
func size() -> int:
	return _obj.size()


## Drop everything without writing it back (the search is finished with
## this line and the game has already been unwound another way).
func clear() -> void:
	_obj.clear()
	_prop.clear()
	_val.clear()
