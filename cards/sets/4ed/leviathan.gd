extends CardScript
## Leviathan — {5}{U}{U}{U}{U} — Creature — Leviathan — 10/10 — (4ed, rare)
## Oracle: Trample
##         This creature enters tapped and doesn't untap during your untap
##         step.
##         At the beginning of your upkeep, you may sacrifice two Islands.
##         If you do, untap this creature.
##         This creature can't attack unless you sacrifice two Islands.
##         (This cost is paid as attackers are declared.)
##
## Implementation: four clauses, four existing engine pieces plus one new
## one. It enters tapped (CardData.with_enters_tapped) and never untaps on
## its own (a static raising cur_skips_untap on itself); the upkeep untap is
## an ordinary trigger paid with two sacrifices; and the attack cost is the
## engine's ATTACK COST list (CardInstance.cur_attack_costs), so declaring
## an attack without two Islands is REFUSED with the reason, and a
## declaration that has to be refused spends nothing.
##
## Four Islands per swing is the printed price, and the parenthetical says
## when it is paid — which is exactly what the attack-cost hook models.
##
## The Islands that go are the player's choice, asked through the agent, and
## the least useful one is offered first.


func build() -> CardData:
	return CardData.new("Leviathan", "{5}{U}{U}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(10, 10) \
		.with_subtypes(["leviathan"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.with_enters_tapped() \
		.static_ability(StaticAbility.new(
			_never_untaps, "This creature doesn't untap during your untap step.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _maybe_untap,
			"At the beginning of your upkeep, you may sacrifice two Islands. If you do, untap this creature.",
			_your_upkeep)) \
		.static_ability(StaticAbility.new(
			_attack_toll, "This creature can't attack unless you sacrifice two Islands.")) \
		.oracle("Trample\nThis creature enters tapped and doesn't untap during your "
			+ "untap step.\nAt the beginning of your upkeep, you may sacrifice two "
			+ "Islands. If you do, untap this creature.\nThis creature can't attack "
			+ "unless you sacrifice two Islands. (This cost is paid as attackers are "
			+ "declared.)")


static func _never_untaps(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


static func _your_upkeep(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


## The Islands [param pid] controls, least useful first (untapped ones are
## kept back, so the heuristic gives up a tapped Island where it can).
static func islands(game: MtgGame, pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.has_subtype("island"):
			out.append(inst)
	out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		if a.tapped != b.tapped:
			return a.tapped
		return a.id < b.id)
	return out


## Sacrifice two Islands, chosen by [param pid]. True when both went.
static func pay_two_islands(game: MtgGame, pid: int) -> bool:
	for _i in 2:
		var pool := islands(game, pid)
		if pool.is_empty():
			return false
		var pick := game.agents[pid].choose_card(game, pid, pool,
			"Sacrifice an Island")
		if pick == null or not pool.has(pick):
			pick = pool[0]
		game.sacrifice_permanent(pick)
	return true


static func _maybe_untap(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or not source.tapped:
		return
	var pid := source.controller_id
	if islands(game, pid).size() < 2:
		return
	if not game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice two Islands to untap Leviathan?", true):
		return
	if pay_two_islands(game, pid):
		game.untap_permanent(source)


static func _attack_toll(_game: MtgGame, source: CardInstance) -> void:
	source.cur_attack_costs.append({
		"desc": "you sacrifice two Islands",
		"can_pay": _has_two_islands,
		"pay": _sacrifice_two,
	})


static func _has_two_islands(game: MtgGame, pid: int) -> bool:
	return islands(game, pid).size() >= 2


static func _sacrifice_two(game: MtgGame, pid: int) -> void:
	pay_two_islands(game, pid)
