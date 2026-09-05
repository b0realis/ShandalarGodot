extends CardScript
## Curse Artifact — {2}{B}{B} — Enchantment — Aura — (drk, uncommon)
## Oracle: Enchant artifact
##         At the beginning of the upkeep of enchanted artifact's
##         controller, this Aura deals 2 damage to that player unless they
##         sacrifice that artifact.
##
## Implementation: Warp Artifact's aura-with-an-upkeep-trigger, with a
## ransom bolted on. "Unless THEY sacrifice" makes the choice the HOST's
## controller's, not the Aura controller's, so the offer goes to that
## seat's DecisionAgent — and the default hint tips towards paying the two
## while the life total can carry it. A host that has left the battlefield
## by the time the trigger resolves cannot be sacrificed, so the two damage
## arrive: the trigger is independent of its source and of the Aura's own
## fate once it is on the stack (CR 603.6).


func build() -> CardData:
	var artifact_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ARTIFACT))
	return CardData.new("Curse Artifact", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(artifact_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _extort,
			"At the beginning of the upkeep of enchanted artifact's controller, this Aura deals 2 damage to that player unless they sacrifice that artifact.",
			_host_controllers_upkeep)) \
		.oracle("Enchant artifact\n"
			+ "At the beginning of the upkeep of enchanted artifact's controller, this Aura "
			+ "deals 2 damage to that player unless they sacrifice that artifact.")


static func _host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == int(event.data["player"])


static func _extort(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD \
			and host.controller_id == pid \
			and game.agents[pid].choose_yes_no(game, pid,
				"Sacrifice %s to %s?" % [host.data.card_name, source.data.card_name],
				game.players[pid].life <= 4):
		game.sacrifice_permanent(host)
		return
	game.deal_damage(source, TargetRef.player(pid), 2)
