extends CardScript
## Vaevictis Asmadi — {2}{B}{B}{R}{R}{G}{G} — Legendary Creature — Elder Dragon — 7/7 — (leg, rare)
## Oracle: Flying
##         At the beginning of your upkeep, sacrifice Vaevictis Asmadi
##         unless you pay {B}{R}{G}.
##         {B}: Vaevictis Asmadi gets +1/+0 until end of turn.
##         {R}: Vaevictis Asmadi gets +1/+0 until end of turn.
##         {G}: Vaevictis Asmadi gets +1/+0 until end of turn.
##
## Implementation: the cycle's upkeep rent plus THREE separate
## firebreathing abilities, one per colour — kept separate (rather than
## folded into one "{B/R/G}" ability) because the printed card lists
## three, and the engine picks an ability by index.


func build() -> CardData:
	return CardData.new("Vaevictis Asmadi", "{2}{B}{B}{R}{R}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(7, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elder", "dragon"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _rent,
			"At the beginning of your upkeep, sacrifice Vaevictis Asmadi unless you "
			+ "pay {B}{R}{G}.",
			_own_upkeep)) \
		.activated(ActivatedAbility.new("{B}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{B}: Vaevictis Asmadi gets +1/+0 until end of turn.")) \
		.activated(ActivatedAbility.new("{R}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{R}: Vaevictis Asmadi gets +1/+0 until end of turn.")) \
		.activated(ActivatedAbility.new("{G}", false,
			[PumpEffect.new(1, 0).self_buff()],
			"{G}: Vaevictis Asmadi gets +1/+0 until end of turn.")) \
		.oracle("Flying\nAt the beginning of your upkeep, sacrifice Vaevictis Asmadi "
			+ "unless you pay {B}{R}{G}.\n{B}: Vaevictis Asmadi gets +1/+0 until end "
			+ "of turn.\n{R}: Vaevictis Asmadi gets +1/+0 until end of turn.\n"
			+ "{G}: Vaevictis Asmadi gets +1/+0 until end of turn.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{B}{R}{G}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {B}{R}{G} to keep Vaevictis Asmadi?", true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
