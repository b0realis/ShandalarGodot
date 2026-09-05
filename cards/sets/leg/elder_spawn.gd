extends CardScript
## Elder Spawn — {4}{U}{U}{U} — Creature — Spawn — 6/6 — (leg, rare)
## Oracle: At the beginning of your upkeep, unless you sacrifice an Island,
##         sacrifice this creature and it deals 6 damage to you.
##         This creature can't be blocked by red creatures.
##
## Implementation: an upkeep trigger that OFFERS the Island through the
## controller's DecisionAgent (choose_yes_no, then choose_card for which
## Island) and otherwise kills the Spawn for six to the face,
## plus a block restriction excluding red creatures. A 6/6 for seven that
## costs you a land every turn.


func build() -> CardData:
	return CardData.new("Elder Spawn", "{4}{U}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(6, 6) \
		.with_subtypes(["spawn"]) \
		.static_ability(StaticAbility.new(
			_apply, "Elder Spawn can't be blocked by red creatures.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _feed,
			"At the beginning of your upkeep, unless you sacrifice an Island, "
			+ "sacrifice Elder Spawn and it deals 6 damage to you.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, unless you sacrifice an Island, "
			+ "sacrifice this creature and it deals 6 damage to you.\nThis creature "
			+ "can't be blocked by red creatures.")


static func _not_red(blocker: CardInstance) -> bool:
	return (blocker.cur_colors & Mtg.ManaColor.R) == 0


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_block_restrictions.append(
		{"desc": "non-red creatures", "filter": _not_red})


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _feed(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	# "Unless you sacrifice an Island" is an OPTIONAL cost: the controller
	# decides whether to pay, and which Island to give up.
	var islands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.has_subtype("island"):
			islands.append(inst)
	if not islands.is_empty() and game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice an Island to keep %s?" % source.data.card_name, true):
		var pick := game.agents[pid].choose_card(game, pid, islands, "Sacrifice an Island")
		game.sacrifice_permanent(pick if pick != null and islands.has(pick) else islands[0])
		return
	game.sacrifice_permanent(source)
	game.deal_damage(source, TargetRef.player(pid), 6)
