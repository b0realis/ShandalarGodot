extends CardScript
## War Barge — {4} — Artifact — (drk, uncommon)
## Oracle: {3}: Target creature gains islandwalk until end of turn. When
##         this artifact leaves the battlefield this turn, destroy that
##         creature. A creature destroyed this way can't be regenerated.
##
## Implementation: the grant is the engine's floating landwalk (the same
## one Scarwood Hag uses), and the Barge remembers every passenger it has
## ferried — stamped with the TURN it ferried them, because the printed
## delayed trigger only lasts "this turn" (CR 603.7a: the delayed ability
## is created by the resolving ability and expires with its duration). A
## Barge sunk on a later turn drowns nobody; the passengers of the current
## turn all go down with it, without regeneration.


func build() -> CardData:
	return CardData.new("War Barge", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{3}", false, [BoardTheBargeEffect.new()],
			"{3}: Target creature gains islandwalk until end of turn.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _sink,
			"When this artifact leaves the battlefield this turn, destroy the creatures it ferried. They can't be regenerated.",
			_is_self_leaving)) \
		.oracle("{3}: Target creature gains islandwalk until end of turn. When this artifact leaves the battlefield this turn, destroy that creature. A creature destroyed this way can't be regenerated. (A creature with islandwalk can't be blocked as long as defending player controls an Island.)")


static func _is_self_leaving(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var parting: Dictionary = event.data.get("memory", {})
	return event.data.get("instance") == source \
		and int(parting.get("passenger_turn", -1)) == game.turn_number \
		and not Array(parting.get("passengers", [])).is_empty()


static func _sink(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var parting: Dictionary = event.data.get("memory", {})
	if int(parting.get("passenger_turn", -1)) != game.turn_number:
		return   # "leaves the battlefield THIS TURN" — an older ferry expired
	for passenger_id in Array(parting.get("passengers", [])):
		var passenger := game.find_instance(int(passenger_id))
		if passenger != null and passenger.zone == Mtg.Zone.BATTLEFIELD:
			game.destroy(passenger, false)


class BoardTheBargeEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var passenger := game.find_instance(target.instance_id)
		if passenger == null or passenger.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_landwalk(passenger.id, ["island"])
		# The manifest belongs to THIS turn only (see the header): a new
		# turn starts a fresh one.
		var manifest: Array = []
		if int(source.memory.get("passenger_turn", -1)) == game.turn_number:
			manifest = source.memory.get("passengers", [])
		if not manifest.has(passenger.id):
			manifest.append(passenger.id)
		source.memory["passengers"] = manifest
		source.memory["passenger_turn"] = game.turn_number
		game.recalculate()

	func describe() -> String:
		return "target creature gains islandwalk until end of turn"
