extends SceneTree
## THE PROBE COST CURVE — what docs/duel-todo.md §1.3's pre-flight actually
## costs as a board grows. Run:
##   ../tools/godot --headless --path . -s res://tools/bench_probe.gd
##
## `GameSnapshot`'s class doc quotes "about 5 ms for a 114-object mid-game
## board". That number is load-bearing (the probe runs once per stack
## resolution, and again after every answer), and it is the kind of number
## that rots silently as CardInstance grows fields. This re-measures it, and
## measures the SHAPE — a rewind is a walk over the object graph, so the
## honest question is whether it is linear in the board or worse.
##
## Three columns per row:
##   take      GameSnapshot.take() alone
##   restore   GameSnapshot.restore() alone
##   preflight the whole MtgGame._preflight(): take + resolve + rewind

## Permanents PER SEAT. A real duel tops out around 20-30 a side; the tail
## is there to show the curve, not because a game gets there.
const BOARDS := [5, 10, 20, 40, 80, 160]

const REPS := 200

## A mixed, ability-heavy spread — statics, triggers and mana abilities, so
## the derived indexes are populated the way a real board populates them.
const FILL := ["Grizzly Bears", "Mountain", "Forest", "Bad Moon", "Wall of Stone",
	"Savannah Lions", "Llanowar Elves", "Crusade", "Air Elemental", "Swamp"]


func _initialize() -> void:
	print("board   objs    take      restore   preflight   per-object")
	print("-----   ----    ------    -------   ---------   ----------")
	for per_seat in BOARDS:
		_measure(per_seat)
	quit()


func _measure(per_seat: int) -> void:
	var game := _build(per_seat)
	# One warm-up: GameSnapshot caches its property-name list per script.
	GameSnapshot.take(game).restore()

	var objs := GameSnapshot.take(game)
	var count := objs.object_count()
	objs.restore()

	var t0 := Time.get_ticks_usec()
	var held: Array = []
	for _i in REPS:
		held.append(GameSnapshot.take(game))
	var take_us := float(Time.get_ticks_usec() - t0) / REPS
	var t1 := Time.get_ticks_usec()
	for snap in held:
		(snap as GameSnapshot).restore()
	var restore_us := float(Time.get_ticks_usec() - t1) / REPS

	var t2 := Time.get_ticks_usec()
	for _i in REPS:
		game._preflight()
	var pre_us := float(Time.get_ticks_usec() - t2) / REPS

	print("%5d   %4d    %6.2fms  %6.2fms  %7.2fms   %6.1fus" % [
		per_seat * 2, count, take_us / 1000.0, restore_us / 1000.0,
		pre_us / 1000.0, (take_us + restore_us) / maxf(count, 1.0)])


## A game with [param per_seat] permanents a side, full hands, stocked
## graveyards, and a Junún Efreet upkeep trigger waiting on the stack — the
## §1.3 shape (45 of the 103 in-resolution asks are upkeep triggers).
func _build(per_seat: int) -> MtgGame:
	var game := MtgGame.new()
	var filler: Array = []
	for _i in 40:
		filler.append("Forest")
	game.setup(filler, filler, "P0", "P1", 20, 20, 20260901)
	game.start(0)
	game.agents[0] = HumanAgent.new()
	game.interactive_choices = true
	for pid in 2:
		for i in per_seat:
			_put(game, pid, FILL[i % FILL.size()])
		for i in 7:
			var inst := _make(game, pid, FILL[i % FILL.size()])
			inst.zone = Mtg.Zone.HAND
			game.players[pid].hand.append(inst)
		for i in 6:
			var dead := _make(game, pid, FILL[i % FILL.size()])
			dead.zone = Mtg.Zone.GRAVEYARD
			game.players[pid].graveyard.append(dead)
	# The item the probe will run: an upkeep trigger with a "pay or
	# sacrifice" question in it.
	var efreet := _put(game, 0, "Junún Efreet")
	var item := StackItem.new()
	item.kind = Mtg.StackKind.TRIGGER
	item.card = efreet
	item.controller = 0
	item.trigger = efreet.data.triggered_abilities[0]
	item.event = GameEvent.new(Mtg.EventType.UPKEEP_START, {"player": 0})
	item.description = "Junún Efreet — upkeep"
	game.stack.append(item)
	game.recalculate()
	return game


func _make(game: MtgGame, pid: int, card_name: String) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	var inst := CardInstance.new(data, game._next_instance_id, pid)
	game._next_instance_id += 1
	game._instances[inst.id] = inst
	return inst


func _put(game: MtgGame, pid: int, card_name: String) -> CardInstance:
	var inst := _make(game, pid, card_name)
	game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst
