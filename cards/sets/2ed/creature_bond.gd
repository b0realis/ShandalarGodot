extends CardScript
## Creature Bond — {1}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant creature
##         When enchanted creature dies, this Aura deals damage equal to
##         that creature's toughness to the creature's controller.
##
## Implementation: a DIES trigger on the AURA, gated on the dying creature
## being its host. The toughness read is LAST KNOWN INFORMATION
## (CardInstance.last_toughness, snapshotted by the zone change —
## CR 608.2h), so a pumped or enchanted creature hits for what it actually
## was; the damage lands on the creature's controller, not the aura's.
## Cast on an opponent's fatty it is a delayed Lava Axe; cast on your own
## it is a Fling.


func build() -> CardData:
	return CardData.new("Creature Bond", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _detonate,
			"When enchanted creature dies, Creature Bond deals damage equal to that "
			+ "creature's toughness to the creature's controller.",
			_host_died)) \
		.oracle("Enchant creature\nWhen enchanted creature dies, this Aura deals "
			+ "damage equal to that creature's toughness to the creature's controller.")


static func _host_died(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var dead: CardInstance = event.data.get("instance")
	return dead != null and dead.id == source.attached_to


static func _detonate(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var dead: CardInstance = event.data["instance"]
	var victim := int(event.data.get("controller", dead.owner_id))
	game.deal_damage(source, TargetRef.player(victim), dead.last_toughness)
