extends CardScript
## Magnetic Mountain — {1}{R}{R} — Enchantment — (4ed, rare)
## Oracle: Blue creatures don't untap during their controllers' untap steps.
##         At the beginning of each player's upkeep, that player may choose
##         any number of tapped blue creatures they control and pay {4}
##         for each creature chosen this way. If the player does, untap
##         those creatures.
##
## Implementation: a static raising cur_skips_untap on every blue creature
## plus an upkeep trigger offering {4} per tapped blue creature through
## the active player's DecisionAgent. The era's hardest blue hoser: a
## Prodigal Sorcerer that untaps once costs its controller four mana a
## turn.


func build() -> CardData:
	return CardData.new("Magnetic Mountain", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Blue creatures don't untap during their controllers' untap steps.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _ransom,
			"At the beginning of each player's upkeep, that player may pay {4} for "
			+ "each tapped blue creature they control to untap it.")) \
		.oracle("Blue creatures don't untap during their controllers' untap steps.\n"
			+ "At the beginning of each player's upkeep, that player may choose any "
			+ "number of tapped blue creatures they control and pay {4} for each "
			+ "creature chosen this way. If the player does, untap those creatures.")


static func _is_blue_creature(inst: CardInstance) -> bool:
	return inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.U) != 0


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if _is_blue_creature(inst):
			inst.cur_skips_untap = true


static func _ransom(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var cost := ManaCost.parse("{4}")
	for inst in game.players[pid].battlefield.duplicate():
		if not _is_blue_creature(inst) or not inst.tapped:
			continue
		if not game.can_afford_cost(pid, cost):
			return
		if not game.agents[pid].choose_yes_no(game, pid,
				"Pay {4} to untap %s?" % inst.data.card_name, true):
			continue
		if game.try_pay(pid, cost):
			game.untap_permanent(inst)
