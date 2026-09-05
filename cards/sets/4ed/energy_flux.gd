extends CardScript
## Energy Flux — {2}{U} — Enchantment — (4ed, uncommon)
## Oracle: All artifacts have "At the beginning of your upkeep, sacrifice
##         this artifact unless you pay {2}."
##
## Implementation: a GRANTED TRIGGERED ABILITY, exactly as printed. The
## Flux is a static ability that appends one "At the beginning of your
## upkeep, sacrifice this artifact unless you pay {2}" trigger to every
## artifact's live list (CardInstance.cur_triggered_abilities, CR 613
## layer 6), and MtgGame.dispatch_event reads that list — so each artifact
## carries its OWN tax:
## - each ability triggers at the beginning of its controller's upkeep and
##   goes on the stack as its own object, controlled by the ARTIFACT's
##   controller (CR 603.2, 603.3), one per artifact — an artifact that
##   arrives while the taxes are on the stack is not taxed this turn, one
##   that leaves in response has its trigger do nothing;
## - the taxes resolve one at a time with priority in between, so a
##   response can come between two of them;
## - an artifact whose abilities are silenced (Titania's Song) has no tax,
##   because the granted ability is silenced with the printed ones.
## The static declares the event type it hands out
## (StaticAbility.granting_triggers) so the dispatcher's early-out index
## counts artifacts as UPKEEP_START listeners while the Flux is out.
## Symmetric, so a blue deck plays few artifacts itself. Lifted 2026-09-02;
## it used to be one trigger on the Flux that walked the board at
## resolution.


func build() -> CardData:
	var tax := TriggeredAbility.new(
		Mtg.EventType.UPKEEP_START, _toll,
		"At the beginning of your upkeep, sacrifice this artifact unless you pay {2}.",
		_own_upkeep)
	return CardData.new("Energy Flux", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_grant.bind(tax),
			"All artifacts have \"At the beginning of your upkeep, sacrifice this "
			+ "artifact unless you pay {2}.\"") \
			.granting_triggers([Mtg.EventType.UPKEEP_START])) \
		.oracle("All artifacts have \"At the beginning of your upkeep, sacrifice this "
			+ "artifact unless you pay {2}.\"")


static func _grant(game: MtgGame, _source: CardInstance, tax: TriggeredAbility) -> void:
	for inst in game.all_battlefield():
		if inst.is_type(Mtg.CardType.ARTIFACT) and not inst.cur_triggered_abilities.has(tax):
			inst.cur_triggered_abilities.append(tax)


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _toll(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{2}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {2} to keep %s?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		return
	game.sacrifice_permanent(source)
