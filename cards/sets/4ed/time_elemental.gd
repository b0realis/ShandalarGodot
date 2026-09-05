extends CardScript
## Time Elemental — {2}{U} — Creature — Elemental — 0/2 — (4ed, rare)
## Oracle: When this creature attacks or blocks, at end of combat,
##         sacrifice it and it deals 5 damage to you.
##         {2}{U}{U}, {T}: Return target permanent that isn't enchanted to
##         its owner's hand.
##
## Implementation: a repeatable Boomerang for any UNENCHANTED permanent
## (lands included — it is the pool's only repeatable land bounce), plus
## the self-immolation. Attacking or blocking triggers, and that trigger
## creates a DELAYED end-of-combat action
## (MtgGame.schedule_end_of_combat_action, the Glyph of Doom machinery):
## the action outlives its source (CR 603.7a), so an Elemental that dies
## in combat, is bounced or is sacrificed still burns its controller for
## five — only the sacrifice half is skipped (CR 608.2, "as much as
## possible"). A 0/2 that should never be in combat.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target permanent that isn't enchanted")
	spec.with_game_filter(_unenchanted)
	return CardData.new("Time Elemental", "{2}{U}", Mtg.CardType.CREATURE) \
		.pt(0, 2) \
		.with_subtypes(["elemental"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DECLARED_ATTACKERS, _schedule_doom,
			"When Time Elemental attacks, at end of combat sacrifice it and "
			+ "it deals 5 damage to you.",
			_self_attacks)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _schedule_doom,
			"When Time Elemental blocks, at end of combat sacrifice it and "
			+ "it deals 5 damage to you.",
			_self_blocks)) \
		.activated(ActivatedAbility.new(
			"{2}{U}{U}", true, [ReturnToHandEffect.new(spec)],
			"{2}{U}{U}, {T}: Return target permanent that isn't enchanted to its "
			+ "owner's hand.")) \
		.oracle("When this creature attacks or blocks, at end of combat, sacrifice it "
			+ "and it deals 5 damage to you.\n{2}{U}{U}, {T}: Return target permanent "
			+ "that isn't enchanted to its owner's hand.")


static func _unenchanted(game: MtgGame, inst: CardInstance) -> bool:
	for aura_id in inst.attachments:
		var aura := game.find_instance(aura_id)
		if aura != null and aura.data.is_aura():
			return false
	return true


static func _self_attacks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return (event.data["attackers"] as Array).has(source)


static func _self_blocks(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("blocker") == source


## The trigger: hand the end-of-combat step a delayed action. The player
## is captured NOW — "you" is the controller of the ability that created
## the delayed trigger (CR 603.7), not whoever holds the corpse later.
static func _schedule_doom(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.schedule_end_of_combat_action(
		_immolate.bind(source.id, source.controller_id))


## The delayed action, running at end of combat with or without its source.
static func _immolate(game: MtgGame, elemental_id: int, pid: int) -> void:
	var elemental := game.find_instance(elemental_id)
	if elemental == null:
		return
	if elemental.zone == Mtg.Zone.BATTLEFIELD:
		game.sacrifice_permanent(elemental)
	game.deal_damage(elemental, TargetRef.player(pid), 5)
