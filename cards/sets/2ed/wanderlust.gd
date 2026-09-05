extends CardScript
## Wanderlust — {2}{G} — Enchantment — Aura (2ed, uncommon)
## Oracle: Enchant creature. At the beginning of the upkeep of enchanted
##         creature's controller, Wanderlust deals 1 damage to that player.
##
## Implementation: Warp Artifact's pattern aimed at creatures — an aura
## whose upkeep trigger reads the live host's controller. Green's odd
## little punisher.


func build() -> CardData:
	return CardData.new("Wanderlust", "{2}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _burn,
			"At the beginning of the upkeep of enchanted creature's controller, Wanderlust deals 1 damage to that player.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant creature. At the beginning of the upkeep of enchanted creature's controller, Wanderlust deals 1 damage to that player.")


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _burn(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
