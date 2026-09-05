extends CardScript
## Yawgmoth Demon — {4}{B}{B} — Creature — Phyrexian Demon — 6/6 — (atq, rare)
## Oracle: Flying (This creature can't be blocked except by creatures with
##         flying or reach.)
##         First strike (This creature deals combat damage before creatures
##         without first strike.)
##         At the beginning of your upkeep, you may sacrifice an artifact.
##         If you don't, tap this creature and it deals 2 damage to you.
##
## Implementation: a 6/6 flying first striker on an artifact diet. The
## upkeep tribute is OPTIONAL — "you may sacrifice an artifact" — so it goes
## through choose_yes_no then choose_card (Elder Spawn's shape); with no
## artifact to feed it, or with the offer declined, the Demon taps itself
## and bites for two. It taps whether or not it was already tapped, and the
## damage is dealt even if the Demon has left the battlefield in response
## (CR 603.6 / 608.2h).


func build() -> CardData:
	return CardData.new("Yawgmoth Demon", "{4}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(6, 6) \
		.with_subtypes(["phyrexian", "demon"]) \
		.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _feed,
			"At the beginning of your upkeep, you may sacrifice an artifact. If you don't, tap this creature and it deals 2 damage to you.",
			_own_upkeep)) \
		.oracle("Flying (This creature can't be blocked except by creatures with flying or reach.)\n"
			+ "First strike (This creature deals combat damage before creatures without first strike.)\n"
			+ "At the beginning of your upkeep, you may sacrifice an artifact. If you don't, tap this creature and it deals 2 damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _cheapest_first(a: CardInstance, b: CardInstance) -> bool:
	return a.data.cost.mana_value() < b.data.cost.mana_value()


static func _feed(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var artifacts: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_type(Mtg.CardType.ARTIFACT):
			artifacts.append(inst)
	if not artifacts.is_empty() and game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice an artifact to %s?" % source.data.card_name, true):
		artifacts.sort_custom(_cheapest_first)
		var pick := game.agents[pid].choose_card(game, pid, artifacts,
			"Sacrifice an artifact")
		game.sacrifice_permanent(pick if pick != null and artifacts.has(pick) else artifacts[0])
		return
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.tap_permanent(source)
	game.deal_damage(source, TargetRef.player(pid), 2)
