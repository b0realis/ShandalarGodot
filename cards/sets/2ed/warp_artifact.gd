extends CardScript
## Warp Artifact — {B}{B} — Enchantment — Aura (2ed, rare)
## Oracle: Enchant artifact. At the beginning of the upkeep of enchanted
##         artifact's controller, Warp Artifact deals 1 damage to that
##         player.
##
## Implementation: an aura on an ARTIFACT carrying an UPKEEP_START trigger
## whose condition reads the HOST's controller from live attachment state —
## the aura-with-trigger pattern (cf. wild_growth.gd for aura-with-mana-
## trigger). Falls off via the normal SBA when the host dies.


func build() -> CardData:
	var artifact_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ARTIFACT))
	return CardData.new("Warp Artifact", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(artifact_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START,
			_burn,
			"At the beginning of the upkeep of enchanted artifact's controller, Warp Artifact deals 1 damage to that player.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant artifact.\nAt the beginning of the upkeep of enchanted artifact's controller, Warp Artifact deals 1 damage to that player.")


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _burn(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
