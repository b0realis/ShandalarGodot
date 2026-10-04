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
## creates a DELAYED TRIGGER for the end of this combat
## (MtgGame.schedule_delayed_trigger, CR 603.7) controlled by the attack /
## block trigger's controller (603.7d). It goes on the stack with the
## step's other end-of-combat triggers in APNAP order (CR 603.3b), and it
## outlives its source (CR 603.7a), so an Elemental that dies in combat,
## is bounced or is sacrificed still burns "you" for five — only the
## sacrifice half is skipped (CR 608.2, "as much as possible"); so does
## one that someone else controls by then, which "you" can't sacrifice
## (CR 701.17a). A 0/2 that should never be in combat.
##
## "Blocks" listens to BECOMES_BLOCKER, once per creature that starts
## blocking (2026-10-03): BLOCKED is one event per block PAIR, and a band
## is one pair per member, so blocking a band of two cost ten life.


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
			Mtg.EventType.BECOMES_BLOCKER, _schedule_doom,
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
	return event.data.get("instance") == source


## The trigger: create the delayed trigger. "You" is the controller of the
## ability that created it (CR 603.7d) — fixed NOW, not whoever holds the
## Elemental or the corpse later. It lasts this turn: its combat ends now.
static func _schedule_doom(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := game.current_resolution_controller()
	if pid < 0:
		pid = source.controller_id
	var trigger := TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
		_immolate.bind(source.id, source.layer_timestamp, pid),
		"At end of combat, sacrifice Time Elemental and it deals 5 damage to you.")
	var entry := game.schedule_delayed_trigger(trigger, pid, source)
	entry["expires_turn"] = game.turn_number


## The delayed trigger, resolving at end of combat with or without its
## source: "you" sacrifice it if it is still that object and still yours
## (CR 400.7, 701.17a), and it deals the 5 damage either way.
static func _immolate(game: MtgGame, _source: CardInstance, _event: GameEvent,
		elemental_id: int, stamp: int, pid: int) -> void:
	var elemental := game.find_instance(elemental_id)
	if elemental == null:
		return
	if elemental.zone == Mtg.Zone.BATTLEFIELD and elemental.layer_timestamp == stamp \
			and elemental.controller_id == pid:
		game.sacrifice_permanent(elemental)
	game.deal_damage(elemental, TargetRef.player(pid), 5)
