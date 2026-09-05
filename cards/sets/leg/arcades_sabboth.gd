extends CardScript
## Arcades Sabboth — {2}{G}{G}{W}{W}{U}{U} — Legendary Creature — Elder Dragon — 7/7 — (leg, rare)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice Arcades Sabboth
##         unless you pay {G}{W}{U}.
##         Each untapped creature you control gets +0/+2 as long as it's
##         not attacking.
##         {W}: Arcades Sabboth gets +0/+1 until end of turn.
##
## Implementation: the cycle's upkeep rent, a firebreathing-shaped
## toughness pump, and a defensive anthem whose static reads LIVE tap
## state and the live combat declarations — so a creature loses the +0/+2
## the moment it is declared as an attacker (attacking taps it anyway,
## unless it has vigilance, which is exactly the case the "not attacking"
## clause is written for).


func build() -> CardData:
	return CardData.new("Arcades Sabboth", "{2}{G}{G}{W}{W}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elder", "dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.static_ability(StaticAbility.new(
			_anthem,
			"Each untapped creature you control gets +0/+2 as long as it's not attacking.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Arcades Sabboth unless you "
			+ "pay {G}{W}{U}.",
			_own_upkeep)) \
		.activated(ActivatedAbility.new("{W}", false,
			[PumpEffect.new(0, 1).self_buff()],
			"{W}: Arcades Sabboth gets +0/+1 until end of turn.")) \
		.oracle("Flying\nAt the beginning of your upkeep, sacrifice Arcades Sabboth "
			+ "unless you pay {G}{W}{U}.\nEach untapped creature you control gets "
			+ "+0/+2 as long as it's not attacking.\n{W}: Arcades Sabboth gets +0/+1 "
			+ "until end of turn.")


static func _anthem(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id or not inst.is_creature():
			continue
		if inst.tapped or game.combat.attackers.has(inst.id):
			continue
		inst.cur_toughness += 2


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{G}{W}{U}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {G}{W}{U} to keep Arcades Sabboth?", true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
