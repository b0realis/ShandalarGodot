extends CardScript
## Sandals of Abdallah — {4} — Artifact — (arn, uncommon)
## Oracle: {2}, {T}: Target creature gains islandwalk until end of turn.
##         When that creature dies this turn, destroy this artifact. (A
##         creature with islandwalk can't be blocked as long as defending
##         player controls an Island.)
##
## Implementation: the grant is the engine's floating landwalk; the rider
## is a delayed trigger the Sandals remember themselves. The card-local
## memory holds the ids the Sandals shod AND the turn they did it, because
## the clause says "THIS TURN" — the ids are ignored once the turn number
## moves on, so a creature shod on turn 4 that dies on turn 9 costs
## nothing. (docs/adding-cards.md's audit note: card memory does not expire
## with the turn on its own.)
##
## Shoeing several creatures over one turn is possible only with several
## Sandals, since the {T} is spent — but the list is a list anyway, so a
## Sandals untapped mid-turn (Twiddle) behaves correctly.


func build() -> CardData:
	return CardData.new("Sandals of Abdallah", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true, [ShoeEffect.new()],
			"{2}, {T}: Target creature gains islandwalk until end of turn. When that creature dies this turn, destroy this artifact.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _shatter,
			"When a creature the Sandals shod this turn dies, destroy this artifact.",
			_wearer_died)) \
		.oracle("{2}, {T}: Target creature gains islandwalk until end of turn. When that "
			+ "creature dies this turn, destroy this artifact. (A creature with islandwalk "
			+ "can't be blocked as long as defending player controls an Island.)")


static func _wearer_died(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if int(source.memory.get("shod_turn", -1)) != game.turn_number:
		return false   # "this turn" — a stale list means nothing
	var dead: CardInstance = event.data["instance"]
	return dead != null and (source.memory.get("shod", []) as Array).has(dead.id)


static func _shatter(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.destroy(source)


class ShoeEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_landwalk(inst.id, ["island"])
		game.recalculate()
		if source.zone != Mtg.Zone.BATTLEFIELD:
			return
		if int(source.memory.get("shod_turn", -1)) != game.turn_number:
			source.memory["shod_turn"] = game.turn_number
			source.memory["shod"] = []
		var shod: Array = source.memory["shod"]
		if not shod.has(inst.id):
			shod.append(inst.id)

	func describe() -> String:
		return "target creature gains islandwalk until end of turn"
