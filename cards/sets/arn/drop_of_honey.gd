extends CardScript
## Drop of Honey — {G} — Enchantment — (arn, rare)
## Oracle: At the beginning of your upkeep, destroy the creature with the
##         least power. It can't be regenerated. If two or more creatures
##         are tied for least power, you choose one of them.
##         When there are no creatures on the battlefield, sacrifice this
##         enchantment.
##
## Implementation: a one-mana Abyss for small creatures. The upkeep sweep
## reads LIVE power (a Sorceress Queen's 0/2 victim is the smallest thing
## on the table) across BOTH battlefields, and the tie is broken by the
## controller's DecisionAgent with the enemy's creatures offered first —
## which is the choice a player would make. "It can't be regenerated" is
## MtgGame.destroy's can_regenerate flag. The last line is a state trigger
## (CardData.sacrifices_when, checked as a state-based action), so a Drop
## of Honey cast onto an empty board buries itself immediately.
##
## Note the printed 1997 card is a TARGETED ability ("bury target creature
## with power no greater than that of any other creature Drop of Honey
## could target", Duel.hlp) — the modern oracle text this pool follows made
## it untargeted, so protection from green no longer saves the smallest
## creature. Oracle wins.


func build() -> CardData:
	return CardData.new("Drop of Honey", "{G}", Mtg.CardType.ENCHANTMENT) \
		.sacrifices_when(_board_is_empty) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _dissolve,
			"At the beginning of your upkeep, destroy the creature with the least power. It can't be regenerated.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, destroy the creature with the least power. "
			+ "It can't be regenerated. If two or more creatures are tied for least power, "
			+ "you choose one of them.\n"
			+ "When there are no creatures on the battlefield, sacrifice this enchantment.")


static func _board_is_empty(game: MtgGame, _source: CardInstance) -> bool:
	for inst in game.all_battlefield():
		if inst.is_creature():
			return false
	return true


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _dissolve(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var least := 0
	var tied: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if not inst.is_creature():
			continue
		if tied.is_empty() or inst.cur_power < least:
			least = inst.cur_power
			tied = [inst]
		elif inst.cur_power == least:
			tied.append(inst)
	if tied.is_empty():
		return
	# The enemy's creatures first: "you choose one of them" is the Drop's
	# controller's choice, and no one feeds their own board to it.
	tied.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return int(a.controller_id == pid) < int(b.controller_id == pid))
	var chosen := game.agents[pid].choose_card(game, pid, tied,
		"Choose the creature %s destroys" % source.data.card_name)
	if chosen == null or not tied.has(chosen):
		chosen = tied[0]
	game.destroy(chosen, false)
