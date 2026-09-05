extends CardScript
## Safe Haven — Land — (drk, rare)
## Oracle: {2}, {T}: Exile target creature you control.
##         At the beginning of your upkeep, you may sacrifice this land. If
##         you do, return each card exiled with this land to the battlefield
##         under its owner's control.
##
## Implementation: a bunker for creatures. "Exiled WITH this land" is a
## link between the two objects, so the Haven remembers the ids it banked
## in its own card-local memory; the memory dies with the land, which is
## right — a Safe Haven that is destroyed strands its prisoners in exile
## forever, exactly as printed.
##
## The release reads the list BEFORE sacrificing the land (the sacrifice is
## part of the same resolution and would wipe the memory), and the
## creatures come back under their OWNER's control — a creature borrowed
## with Control Magic and then tucked away goes home.
##
## Producing no mana at all, the Haven is a real cost: it is a land slot.


func build() -> CardData:
	var yours := TargetSpec.creature("target creature you control")
	yours.with_source_filter(_yours)
	return CardData.new("Safe Haven", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new(
			"{2}", true, [BankEffect.new(yours)],
			"{2}, {T}: Exile target creature you control.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _release,
			"At the beginning of your upkeep, you may sacrifice this land. If you do, return each card exiled with this land to the battlefield under its owner's control.",
			_own_upkeep)) \
		.oracle("{2}, {T}: Exile target creature you control.\n"
			+ "At the beginning of your upkeep, you may sacrifice this land. If you do, "
			+ "return each card exiled with this land to the battlefield under its owner's control.")


static func _yours(_game: MtgGame, source: CardInstance, inst: CardInstance) -> bool:
	return inst.controller_id == source.controller_id


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id \
		and not (source.memory.get("banked", []) as Array).is_empty()


static func _release(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	if not game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice %s to bring its prisoners back?" % source.data.card_name, true):
		return
	# Read the list first: sacrificing the land wipes its memory.
	var banked: Array = (source.memory.get("banked", []) as Array).duplicate()
	game.sacrifice_permanent(source)
	for id in banked:
		var inst := game.find_instance(int(id))
		if inst != null and inst.zone == Mtg.Zone.EXILE:
			game.return_from_exile_to_play(inst, inst.owner_id)


class BankEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.exile_permanent(inst)
		if source.zone != Mtg.Zone.BATTLEFIELD or inst.zone != Mtg.Zone.EXILE:
			return   # a token ceased to exist; nothing to remember
		var banked: Array = source.memory.get("banked", [])
		if not banked.has(inst.id):
			banked.append(inst.id)
		source.memory["banked"] = banked

	func describe() -> String:
		return "exiles target creature you control until the Haven is sacrificed"
