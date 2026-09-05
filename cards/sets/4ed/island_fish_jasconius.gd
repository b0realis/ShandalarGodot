extends CardScript
## Island Fish Jasconius — {4}{U}{U}{U} — Creature — Fish — 6/8 — (4ed, rare)
## Oracle: This creature doesn't untap during your untap step.
##         At the beginning of your upkeep, you may pay {U}{U}{U}. If you
##         do, untap this creature.
##         This creature can't attack unless defending player controls an
##         Island.
##         When you control no Islands, sacrifice this creature.
##
## Implementation: four printed clauses, four engine mechanics already in
## place — Brass Man's cur_skips_untap static and its "pay to untap" upkeep
## offer, Sea Serpent's attack restriction
## (CardData.attack_needs_defender_land) and Dandân's state trigger
## (CardData.sacrifice_if_no_land_type, checked as a state-based action).
## Note the two Island clauses look at DIFFERENT players: the attack asks
## about the DEFENDER's Islands, the sacrifice about your own.


func build() -> CardData:
	return CardData.new("Island Fish Jasconius", "{4}{U}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(6, 8) \
		.with_subtypes(["fish"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.static_ability(StaticAbility.new(
			_lock, "This creature doesn't untap during your untap step.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _offer_untap,
			"At the beginning of your upkeep, you may pay {U}{U}{U}. If you do, untap this creature.",
			_own_upkeep)) \
		.oracle("This creature doesn't untap during your untap step.\n"
			+ "At the beginning of your upkeep, you may pay {U}{U}{U}. If you do, untap this creature.\n"
			+ "This creature can't attack unless defending player controls an Island.\n"
			+ "When you control no Islands, sacrifice this creature.")


static func _lock(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _offer_untap(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{U}{U}{U}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {U}{U}{U} to untap %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.untap_permanent(source)
