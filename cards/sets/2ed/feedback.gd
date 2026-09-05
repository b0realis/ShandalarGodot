extends CardScript
## Feedback — {2}{U} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant enchantment
##         At the beginning of the upkeep of enchanted enchantment's
##         controller, this Aura deals 1 damage to that player.
##
## Implementation: Cursed Land's blue cousin, on an ENCHANTMENT host —
## blue's era tax on Crusades and Bad Moons. Same upkeep-of-the-host's-
## controller trigger, source = the aura (a blue source).


func build() -> CardData:
	var ench_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ENCHANTMENT))
	return CardData.new("Feedback", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(ench_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _sting,
			"At the beginning of the upkeep of enchanted enchantment's controller, this Aura deals 1 damage to that player.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant enchantment\nAt the beginning of the upkeep of enchanted enchantment's controller, this Aura deals 1 damage to that player.")


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
