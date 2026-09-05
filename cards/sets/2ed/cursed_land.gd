extends CardScript
## Cursed Land — {2}{B}{B} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant land
##         At the beginning of the upkeep of enchanted land's controller,
##         this Aura deals 1 damage to that player.
##
## Implementation: an aura on a LAND whose upkeep trigger matches when the
## upkeep player controls the host — the damage source is the AURA (a
## black source: CoP Black eats it). The drip lands on whoever controls
## the land, so donating the land doesn't stop the bleeding.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Cursed Land", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _sting,
			"At the beginning of the upkeep of enchanted land's controller, this Aura deals 1 damage to that player.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant land\nAt the beginning of the upkeep of enchanted land's controller, this Aura deals 1 damage to that player.")


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
