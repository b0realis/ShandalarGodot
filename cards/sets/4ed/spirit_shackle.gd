extends CardScript
## Spirit Shackle — {B}{B} — Enchantment — Aura — (4ed, uncommon)
## Oracle: Enchant creature
##         Whenever enchanted creature becomes tapped, put a -0/-2 counter
##         on it.
##
## Implementation: a BECAME_TAPPED trigger adding a "-0/-2" counter — the
## continuous pipeline parses P/T counter names, so an invented kind like
## this just works and stacks. Every attack (or tap ability) shaves two
## toughness off permanently; the host usually dies within two swings.


func build() -> CardData:
	return CardData.new("Spirit Shackle", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _shackle,
			"Whenever enchanted creature becomes tapped, put a -0/-2 counter on it.",
			_host_tapped)) \
		.oracle("Enchant creature\nWhenever enchanted creature becomes tapped, put a "
			+ "-0/-2 counter on it.")


static func _host_tapped(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.id == source.attached_to


static func _shackle(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(host, "-0/-2", 1)
