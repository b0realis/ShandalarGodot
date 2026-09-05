extends CardScript
## Blight — {B}{B} — Enchantment — Aura — (4ed, uncommon)
## Oracle: Enchant land
##         When enchanted land becomes tapped, destroy it.
##
## Implementation: a BECAME_TAPPED trigger (the universal tap event) gated
## on the tapped permanent being this aura's host. Because the event fires
## for taps of every kind, the land dies whether it was tapped for mana,
## by an Icy Manipulator, or as a cost.


func build() -> CardData:
	return CardData.new("Blight", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _wither,
			"When enchanted land becomes tapped, destroy it.",
			_host_tapped)) \
		.oracle("Enchant land\nWhen enchanted land becomes tapped, destroy it.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _host_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.id == source.attached_to


static func _wither(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		game.destroy(host)
