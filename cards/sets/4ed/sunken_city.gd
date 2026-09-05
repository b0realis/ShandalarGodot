extends CardScript
## Sunken City — {U}{U} — Enchantment — (4ed, common)
## Oracle: At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay {U}{U}.
##         Blue creatures get +1/+1.
##
## Implementation: a global anthem for ALL blue creatures (both players —
## as printed) plus the standard "sacrifice unless you pay" upkeep rent.


func build() -> CardData:
	return CardData.new("Sunken City", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_anthem, "Blue creatures get +1/+1.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _toll,
			"At the beginning of your upkeep, sacrifice this enchantment unless you pay {U}{U}.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, sacrifice this enchantment unless you pay {U}{U}.\nBlue creatures get +1/+1.")


static func _anthem(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.U) != 0:
			inst.cur_power += 1
			inst.cur_toughness += 1


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["player"] == source.controller_id


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{U}{U}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {U}{U} to keep %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
