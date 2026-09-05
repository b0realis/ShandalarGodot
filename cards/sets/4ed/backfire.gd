extends CardScript
## Backfire — {U} — Enchantment — Aura — (4ed, uncommon)
## Oracle: Enchant creature
##         Whenever enchanted creature deals damage to you, this Aura
##         deals that much damage to that creature's controller.
##
## Implementation: a DAMAGE_DEALT trigger matching host-damage aimed at
## the AURA's controller; the reflection's source is the Aura itself (a
## blue source — CoP: Blue eats it). Cast it on their biggest attacker
## and share the pain.


func build() -> CardData:
	return CardData.new("Backfire", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _reflect,
			"Whenever enchanted creature deals damage to you, this Aura deals that much damage to that creature's controller.",
			_host_hit_me)) \
		.oracle("Enchant creature\nWhenever enchanted creature deals damage to you, this Aura deals that much damage to that creature's controller.")


static func _host_hit_me(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	if not (event.data.get("source") is CardInstance):
		return false
	if (event.data["source"] as CardInstance).id != source.attached_to:
		return false
	return event.data.get("to_player", -1) == source.controller_id


static func _reflect(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	var victim: int = host.controller_id if host != null \
		else (event.data["source"] as CardInstance).controller_id
	game.deal_damage(source, TargetRef.player(victim), event.data["amount"])
