extends CardScript
## Johan — {3}{R}{G}{W} — Legendary Creature — Human Wizard — 5/4 — (leg, rare)
## Oracle: At the beginning of combat on your turn, you may have Johan gain
##         "Johan can't attack" until end of combat. If you do, attacking
##         doesn't cause creatures you control to tap this combat if Johan
##         is untapped.
##
## Implementation: a COMBAT_START trigger (Mtg.EventType.COMBAT_START, new)
## offering the bargain — Johan sits this combat out and everybody else
## attacks without tapping, which is the whole card: a five-power body
## traded for a team of vigilant ones.
##
## Both halves are engine flags rather than card bookkeeping:
## CardInstance.cant_attack_this_turn for Johan's own ban (the closest
## duration the engine has to "until end of combat" for an attack ban, and
## indistinguishable here since combat happens once a turn), and
## MtgGame.attacks_without_tapping for the team, which declare_attackers
## reads and which clears when the combat PHASE ends (CR 700.5).
##
## "If Johan is untapped" is checked as the offer is taken: a Johan who is
## already tapped has nothing to trade, so the trigger declines itself.


func build() -> CardData:
	return CardData.new("Johan", "{3}{R}{G}{W}", Mtg.CardType.CREATURE) \
		.pt(5, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "wizard"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.COMBAT_START, _offer,
			"At the beginning of combat on your turn, you may have Johan sit out so your other creatures attack without tapping.",
			_your_combat)) \
		.oracle("At the beginning of combat on your turn, you may have Johan gain "
			+ "\"Johan can't attack\" until end of combat. If you do, attacking "
			+ "doesn't cause creatures you control to tap this combat if Johan is "
			+ "untapped.")


static func _your_combat(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _offer(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or source.tapped:
		return
	var pid := source.controller_id
	# Worth it when there is a team to keep back — the heuristic's answer.
	var others := 0
	for inst in game.players[pid].battlefield:
		if inst != source and inst.is_creature() and not inst.summoning_sick:
			others += 1
	if not game.agents[pid].choose_yes_no(game, pid,
			"Keep Johan home so your other creatures attack without tapping?",
			others >= 2):
		return
	source.cant_attack_this_turn = true
	game.attacks_without_tapping[pid] = true
	game.recalculate()
	game.log_line("Johan holds the line — %s's creatures attack without tapping"
		% game.players[pid].player_name)
