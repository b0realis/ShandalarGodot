class_name GameSnapshot
extends RefCounted
## A REWIND POINT for the whole engine — the thing that lets [MtgGame] run a
## resolution twice: once as a QUESTION PROBE nobody sees, then for real with
## the player's own answers in hand (docs/duel-todo.md §1.3).
##
## WHY IT EXISTS. The engine is synchronous: when Junún Efreet's upkeep
## trigger resolves it calls `choose_yes_no` right then and needs the answer
## before the call returns, so no UI can open a dialog in the middle of it.
## The old half-fix was memory — MtgGame.choice_history remembered what a
## card asked LAST time, so the player could answer in advance from that
## card's second resolution onward. The first ask still fell to a heuristic.
## With a rewind point the engine can find the question the FIRST time too:
## run the resolution, note what it asked, put everything back, and hold the
## resolution open until the player answers.
##
## HOW. GDScript has no exceptions and no persistent data structures, so the
## rewind is reflective and IN PLACE: every object of mutable game state
## reachable from the game has each of its script variables read out into a
## copy, and [method restore] writes those values back onto THE SAME
## objects. Nothing is cloned, so every reference anyone else is holding — a
## UI's selected card, an agent's cached permanent — stays valid across a
## rewind. Objects created during the probe (tokens, stack items) simply
## become unreferenced when the arrays that held them are restored.
##
## WHAT IS STATE AND WHAT IS DEFINITION. [constant STATE_CLASSES] is the
## whole list — the game, its players, card instances, the mana pools, the
## combat state, the continuous-effect layers, stack items and the events
## they carry — plus every [DecisionAgent], whatever subclass, because a
## seat's mailbox is state the probe consumes. Everything else reachable —
## CardData, CardScript, the abilities, the effects — is a DEFINITION,
## shared by every instance of a card and never written to by a resolution
## (CONTRIBUTING.md rule 5: rules code writes `cur_*` on the instance, never
## `data.*`). Walking them would cost more than the whole rest of the
## snapshot and buy nothing.
##
## LIMITS, and they are load-bearing:
## - Anything OUTSIDE the object graph is not rewound. Signals are the big
##   one — MtgGame silences its own log, events and state signals while
##   probing ([method MtgGame.is_probing]) because a listener's reaction
##   cannot be undone from here.
## - `rng.state` is saved and restored, so a probe that flips a coin does not
##   change what the real resolution flips (CONTRIBUTING.md rule 7).
## - It is a REWIND, not a fork: only one snapshot may be live at a time, it
##   must be restored before the game is touched again, and [method restore]
##   is one shot.
##
## AND IT IS THE WRONG TOOL FOR A SEARCH, which is why [UndoLog] exists.
## The cost below is LINEAR IN THE BOARD; a search move is not. Measured
## 2026-09-02 (`tools/bench_undo.gd`): on the 127-object board below,
## take + restore is 3.44 ms and the move it wraps — cast a creature,
## resolve it, run state-based actions — is 139 us, so 96% of a
## snapshot-per-node is this file. A move changes 1-4 objects and 2-10
## fields whatever the board size, and journaling exactly those is 21x
## cheaper (docs/ROADMAP.md, M4 phase 3). Nothing here needs fixing: a
## pre-flight probe is a few times a second and this is the right shape
## for it.
##
## COST: LINEAR in the number of objects captured, at about 23 microseconds
## each (take + restore), and a whole pre-flight — take, resolve, rewind — is
## roughly 3 ms on a 129-object early board and under 20 ms on a 439-object one
## with 320 permanents on the table (measured 2026-09-01, Godot 4.7.2
## headless; re-run `tools/bench_probe.gd`). A probe pays it once per
## resolution, plus once more after each answer, which is a few times a
## second at duel pace and never inside a frame budget that matters.
##
## Five things keep it there, and each was worth 10-45%:
## - the property-name list is cached per script, as StringNames, so no
##   Object.get()/set() pays for a String conversion;
## - the values are saved POSITIONALLY against that cached list rather than
##   into a Dictionary keyed by name — 78 hashed inserts per CardInstance
##   cost more than reading the 78 values did;
## - properties DECLARED as scalars skip the copy-and-scan call entirely
##   (59 of a CardInstance's 78);
## - a TYPED array answers what its elements are without looking at them, so
##   `Array[int]` needs no walk and `Array[CardInstance]` needs only the
##   enqueue;
## - every object met is marked seen, definitions included, so the CardData
##   a hundred instances share is examined once instead of a hundred times.
## Copy+scan is still a single walk.

## The classes whose script variables ARE the game state. Anything reachable
## that is not one of these is a shared definition and is left alone.
const STATE_CLASSES := {
	"MtgGame": true,
	"MtgPlayer": true,
	"CardInstance": true,
	"ManaPool": true,
	"CombatState": true,
	"ContinuousEffects": true,
	"StackItem": true,
	"GameEvent": true,
	"TargetRef": true,
	"TargetPlan": true,
	"DamagePacket": true,
	"PlayerChoice": true,
	"RulesOptions": true,
}

## script instance id -> [Array[StringName] plain, Array[StringName] deep].
## get_property_list() allocates a Dictionary per property; a 78-variable
## CardInstance times a hundred instances made that the cost of a probe.
##
## The SPLIT is the second half of the same saving. A property DECLARED as a
## scalar (`var tapped: bool`, `var damage: int`) can never hold a container
## or an object, so it needs neither copying nor scanning — reading and
## writing the Variant is the whole job. Only the untyped ones and the
## declared Array/Dictionary/Object/Packed ones go through
## [method _copy_and_scan]. On a CardInstance that is 59 properties out of
## 78 that skip a call each way.
static var _props_by_script: Dictionary = {}

## script instance id -> bool: is an object of this script GAME STATE?
## Answering it costs a get_global_name() plus a Dictionary probe plus an
## `is DecisionAgent` test, and the walk meets the same handful of DEFINITION
## scripts (CardData, the effects, the abilities) once per card in play.
static var _is_state_by_script: Dictionary = {}

var _game: MtgGame = null
var _objects: Array = []    ## the objects captured, parallel with the two below
## Per captured object, its saved property values IN THE CACHED ORDER — a
## flat Array, not a Dictionary keyed by name. Building 78 String-keyed
## Dictionary entries per CardInstance cost more than reading the values
## did; positions cost nothing and the names are already cached per script.
var _values: Array = []
var _props: Array = []      ## per captured object, its _property_names split
var _rng_state: int = 0
var _spent := false         ## restore() is one shot — see its doc


## Capture [param game] and everything mutable it can reach.
static func take(game: MtgGame) -> GameSnapshot:
	var snap := GameSnapshot.new()
	snap._capture(game)
	return snap


func _capture(game: MtgGame) -> void:
	_game = game
	_rng_state = game.rng.state
	var seen := {}
	var queue: Array = [game]
	while not queue.is_empty():
		var obj: Object = queue.pop_back()
		if obj == null:
			continue
		var oid := obj.get_instance_id()
		if seen.has(oid):
			continue
		# EVERY object met is marked seen, definitions included. A skipped
		# object is never walked, so skipping it twice can only cost: a
		# hundred CardInstances point at the same handful of CardData, and
		# each of those used to be re-examined a hundred times.
		seen[oid] = true
		var script: Script = obj.get_script()
		if script == null:
			continue
		if not _is_state(script, obj):
			continue
		var props: Array = _property_names(script, obj)
		var plain: Array = props[0]
		var deep: Array = props[1]
		var saved: Array = []
		saved.resize(plain.size() + deep.size())
		var k := 0
		for name in plain:         # scalars: read and write, nothing else
			saved[k] = obj.get(name)
			k += 1
		for name in deep:
			# One pass: copy the value AND collect the objects it reaches.
			# Walking the same nested containers twice was a third of the
			# cost of a probe.
			saved[k] = _copy_and_scan(obj.get(name), queue)
			k += 1
		_objects.append(obj)
		_values.append(saved)
		_props.append(props)


## Put every captured value back where it came from. The game is exactly as
## it was; anything the probe created is now unreferenced.
##
## ONE SHOT: the saved containers are handed straight back rather than copied
## again (copying twice doubled the cost of a probe for nothing), so from
## here the snapshot and the game share them. A second call is a no-op.
func restore() -> void:
	if _spent:
		return
	_spent = true
	for i in _objects.size():
		var obj: Object = _objects[i]
		var saved: Array = _values[i]
		var props: Array = _props[i]
		var k := 0
		for name in props[0]:
			obj.set(name, saved[k])
			k += 1
		for name in props[1]:
			obj.set(name, saved[k])
			k += 1
	if _game != null:
		_game.rng.state = _rng_state


## How many objects this snapshot holds — for tests and for sizing.
func object_count() -> int:
	return _objects.size()


## Is an object of [param script] GAME STATE (and so captured), or a shared
## DEFINITION (and so left alone)? Memoized per script — see
## [member _is_state_by_script].
static func _is_state(script: Script, obj: Object) -> bool:
	var key := script.get_instance_id()
	var known: Variant = _is_state_by_script.get(key)
	if known != null:
		return bool(known)
	# The agents are rewound too, whatever subclass they are. That is what
	# makes a probe invisible to the seat being probed: HumanAgent's mailbox
	# is CONSUMED by the probe exactly as it would be by the real
	# resolution, and then handed back untouched for the real one.
	var answer: bool = STATE_CLASSES.has(script.get_global_name()) \
		or (obj is DecisionAgent)
	_is_state_by_script[key] = answer
	return answer


## `[plain, deep]` — this script's variable names split by whether their
## value needs copying. See [member _props_by_script].
static func _property_names(script: Script, obj: Object) -> Array:
	var key := script.get_instance_id()
	if _props_by_script.has(key):
		return _props_by_script[key]
	# StringName keys, kept as they come out of get_property_list(): every
	# Object.get()/set() with a String argument pays for the conversion.
	var plain: Array[StringName] = []
	var deep: Array[StringName] = []
	for p in obj.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var pname: StringName = p["name"]
		var ptype := int(p["type"])
		# TYPE_NIL is an UNTYPED `var` (PROPERTY_USAGE_NIL_IS_VARIANT):
		# it can hold anything, so it goes the deep way.
		if ptype == TYPE_NIL or ptype == TYPE_OBJECT or ptype == TYPE_ARRAY \
				or ptype == TYPE_DICTIONARY or ptype >= TYPE_PACKED_BYTE_ARRAY:
			deep.append(pname)
		else:
			plain.append(pname)
	var split: Array = [plain, deep]
	_props_by_script[key] = split
	return split


## Copy one property value AND enqueue every Object it can reach.
##
## Arrays, Dictionaries and the Packed*Array family all SHARE their storage
## when a Variant is copied, so each has to be duplicated — a Packed array
## reached through `Object.get()` looks like a value but is copy-on-write
## with the original, and appending to `log_lines` would edit the snapshot
## too. Objects are NEVER duplicated: they are captured in their own right,
## which is what preserves identity and sharing across a rewind.
static func _copy_and_scan(value: Variant, queue: Array) -> Variant:
	var t := typeof(value)
	if t == TYPE_OBJECT:
		if value != null:
			queue.append(value)
		return value
	if t == TYPE_ARRAY:
		var arr := value as Array
		var out := arr.duplicate()   # shallow; nested below
		# A TYPED array answers what its elements are without looking at
		# them: `Array[CardInstance]` needs only the enqueue, `Array[int]`
		# and `Array[String]` need nothing at all. The zone arrays, the
		# keyword lists and the subtype lists are all one of those, and
		# they are most of the arrays in the game.
		var elem := arr.get_typed_builtin()
		if elem == TYPE_OBJECT:
			queue.append_array(out)
			return out
		if elem != TYPE_NIL and elem != TYPE_ARRAY and elem != TYPE_DICTIONARY \
				and elem < TYPE_PACKED_BYTE_ARRAY:
			return out
		for i in out.size():
			out[i] = _copy_and_scan(out[i], queue)
		return out
	if t == TYPE_DICTIONARY:
		var dict := value as Dictionary
		var copy := dict.duplicate()
		for k in dict:
			_copy_and_scan(k, queue)   # keys: scanned, copied by duplicate()
			copy[k] = _copy_and_scan(dict[k], queue)
		return copy
	if t >= TYPE_PACKED_BYTE_ARRAY:
		return value.duplicate()
	return value
