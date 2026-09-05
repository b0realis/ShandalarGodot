extends CardScript
## Cyclopean Tomb — {4} — Artifact — (2ed, rare)
## Oracle: {2}, {T}: Put a mire counter on target non-Swamp land. That land
##         is a Swamp for as long as it has a mire counter on it. Activate
##         only during your upkeep.
##         When this artifact is put into a graveyard from the battlefield,
##         at the beginning of each of your upkeeps for the rest of the
##         game, remove all mire counters from a land that a mire counter
##         was put onto with this artifact but that a mire counter has not
##         been removed from with this artifact.
##
## Implementation: the mire counters are real counters on the land, and
## "that land is a Swamp for as long as it has a mire counter on it" is a
## static that OUTLIVES the Tomb — on the battlefield the Tomb's own, and
## as it leaves (CardData.as_it_leaves) the same one registered as a
## FLOATING static with no end (ContinuousEffects.add_floating_static,
## INDEFINITE): a land keeps its mire counters, and so its Swampness,
## until something removes them.
##
## The second paragraph is a DELAYED triggered ability (CR 603.7) the
## dies-trigger creates: at the beginning of EACH of the controller's
## upkeeps for the rest of the game (a repeating entry on
## MtgGame.delayed_triggers) they choose one land the Tomb mired and has
## not yet reverted, and remove all mire counters from it. "A land that a
## mire counter was put onto with this artifact": the Tomb keeps the ids
## of the lands it mired in its card memory, and the dies-trigger copies
## that list out of the parting snapshot (CR 400.7 wipes the memory with
## the zone change) into the entry's own memory (MtgGame.current_delayed),
## where each firing strikes one off; a land that has left the battlefield
## is a new object when it returns and drops off the list. When the list
## is spent the entry retires — a trigger with nothing left to revert
## would only clutter the stack. Which land is the controller's choice
## (`@CYCLOPEAN_TOMB_EFFECT`, `Program/promptsX1.txt:104`: "Cyclopean
## Tomb: Select land to revert."); the heuristic reverts its own lands
## first, the opponent's last, so their mired lands stay Swamps longest.
##
## A Tomb EXILED or BOUNCED creates no such trigger — the printed
## condition is "put into a graveyard from the battlefield" — and the
## mired lands then stay Swamps for good.


static func _non_swamp_land(inst: CardInstance) -> bool:
	return inst.is_land() and not inst.has_subtype("swamp")


func build() -> CardData:
	return CardData.new("Cyclopean Tomb", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(_mires_are_swamps_static()) \
		.activated(ActivatedAbility.new("{2}", true,
			[MireEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target non-Swamp land", _non_swamp_land))],
			"{2}, {T}: Put a mire counter on target non-Swamp land.") \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.as_it_leaves(_keep_the_mires) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _start_the_reversion,
			"When Cyclopean Tomb is put into a graveyard from the battlefield, at the beginning of each of your upkeeps for the rest of the game, remove all mire counters from a land it mired.",
			_is_self)) \
		.oracle("{2}, {T}: Put a mire counter on target non-Swamp land. That land is a Swamp for as long as it has a mire counter on it. Activate only during your upkeep.\nWhen this artifact is put into a graveyard from the battlefield, at the beginning of each of your upkeeps for the rest of the game, remove all mire counters from a land that a mire counter was put onto with this artifact but that a mire counter has not been removed from with this artifact.")


static func _mires_are_swamps_static() -> StaticAbility:
	return StaticAbility.new(_mires_are_swamps,
		"Each land with a mire counter on it is a Swamp.") \
		.changing_land_types()


static func _mires_are_swamps(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and int(inst.counters.get("mire", 0)) > 0:
			inst.become_basic_land_type("swamp", Mtg.ManaColor.B)


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## The Tomb is gone; the mire counters are not. The Swampness they grant
## goes on without it (a floating static with no end).
static func _keep_the_mires(game: MtgGame, source: CardInstance, _controller: int,
		_parting: Dictionary) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and int(inst.counters.get("mire", 0)) > 0:
			game.continuous.add_floating_static(source, _mires_are_swamps_static(),
				ContinuousEffects.Duration.INDEFINITE)
			return


static func _start_the_reversion(game: MtgGame, source: CardInstance,
		event: GameEvent) -> void:
	var parting: Dictionary = event.data.get("memory", {})
	var mired: Array = parting.get("mired", []).duplicate()
	if mired.is_empty():
		return   # it never mired anything: nothing to revert, ever
	var controller := int(event.data.get("controller", source.controller_id))
	game.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _revert_one,
		"At the beginning of each of your upkeeps, remove all mire counters from a land Cyclopean Tomb mired.",
		_upkeep_of.bind(controller)), controller, source, true,
		{"mired": mired}, "Cyclopean Tomb's reversion")


static func _upkeep_of(_game: MtgGame, _source: CardInstance, event: GameEvent,
		controller: int) -> bool:
	return int(event.data["player"]) == controller


static func _revert_one(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var entry := game.current_delayed()
	if entry.is_empty():
		return
	var memory: Dictionary = entry["memory"]
	var mired: Array = memory.get("mired", [])
	var controller := int(event.data["player"])
	# Only lands still on the battlefield: one that left is a new object
	# when it returns, and no longer "a land a mire counter was put onto".
	var candidates: Array[CardInstance] = []
	var still: Array = []
	for land_id in mired:
		var land := game.find_instance(int(land_id))
		if land != null and land.zone == Mtg.Zone.BATTLEFIELD and land.is_land():
			candidates.append(land)
			still.append(land_id)
	memory["mired"] = still
	if candidates.is_empty():
		game.retire_delayed_trigger(int(entry["id"]))
		return
	candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var a_mine := a.controller_id == controller
		var b_mine := b.controller_id == controller
		if a_mine != b_mine:
			return a_mine
		return a.id < b.id)
	var pick := game.agents[controller].choose_card(game, controller, candidates,
		"Cyclopean Tomb: Select land to revert.")
	if pick == null or not candidates.has(pick):
		pick = candidates[0]
	game.log_line("Cyclopean Tomb: %s reverts" % pick.data.card_name)
	game.remove_counters(pick, "mire", int(pick.counters.get("mire", 0)))
	still.erase(pick.id)
	memory["mired"] = still
	if still.is_empty():
		game.retire_delayed_trigger(int(entry["id"]))


class MireEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var land := game.find_instance(target.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.add_counters(land, "mire", 1)
		# Remembered for the reversion after the Tomb is gone.
		var mired: Array = source.memory.get("mired", [])
		if not mired.has(land.id):
			mired.append(land.id)
		source.memory["mired"] = mired

	func describe() -> String:
		return "puts a mire counter on target non-Swamp land, making it a Swamp"
