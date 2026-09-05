extends CardScript
## Spitting Slug — {1}{G}{G} — Creature — Slug — 2/4 — (drk, uncommon)
## Oracle: Whenever this creature blocks or becomes blocked, you may pay
##         {1}{G}. If you do, this creature gains first strike until end of
##         turn. Otherwise, each creature blocking or blocked by this
##         creature gains first strike until end of turn.
##
## Implementation: a BLOCKED trigger — the engine fires one per declared
## block PAIR — matching whichever side of the pair the Slug is on. Paying
## gives the Slug first strike; NOT paying hands first strike to everything
## it is fighting, which is the real cost of a cheap 2/4.
##
## Blockers are declared before the first-strike damage step exists, and
## the engine freezes first-strike membership only when that step BEGINS,
## so a grant made here is in time either way.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.
## (The hint is "pay", since the alternative arms the enemy.)


func build() -> CardData:
	return CardData.new("Spitting Slug", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["slug"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _spit,
			"Whenever this creature blocks or becomes blocked, you may pay {1}{G}. If you do, this creature gains first strike until end of turn. Otherwise, each creature blocking or blocked by this creature gains first strike until end of turn.",
			_in_the_pair)) \
		.oracle("Whenever this creature blocks or becomes blocked, you may pay {1}{G}. If "
			+ "you do, this creature gains first strike until end of turn. Otherwise, each "
			+ "creature blocking or blocked by this creature gains first strike until end of turn.")


## "Whenever this creature BLOCKS or BECOMES BLOCKED" — both halves are
## ONE event per declaration however many creatures are on the other
## side (CR 509.1h): "becomes blocked" with no "by a creature" fires once
## for any number of blockers (unlike Cockatrice/Venom/Giant Shark, whose
## printed "by a <filter> creature" really is per blocker), and "blocks"
## fires once even when the Slug blocks two attackers (a Blaze of Glory
## conscript). The engine dispatches BLOCKED once per declared PAIR, so
## each side counts only the FIRST pair it appears in — the first blocker
## when the Slug attacks, the first attacker when it blocks.
static func _in_the_pair(game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var blocker: CardInstance = event.data["blocker"]
	var attacker: CardInstance = event.data["attacker"]
	if blocker == source:
		var attacked := game.combat.attackers_blocked_by(source.id)
		return not attacked.is_empty() and attacker != null \
			and attacked[0] == attacker.id
	if attacker != source:
		return false
	var blockers := game.combat.blockers_of(source.id)
	return not blockers.is_empty() and blocker != null \
		and blockers[0] == blocker.id


## Every creature this one is currently blocking or being blocked by — the
## whole band when the Slug blocks a bander, every blocker when it attacks.
static func _engaged_with(game: MtgGame, source: CardInstance) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if game.combat.attackers.has(source.id):
		for id in game.combat.blockers_of_band(game.combat.band_of(source.id)):
			var inst := game.find_instance(int(id))
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				out.append(inst)
	elif game.combat.blocks.has(source.id):
		for id in game.combat.opposing_attackers(source.id):
			var inst := game.find_instance(int(id))
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				out.append(inst)
	return out


static func _spit(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var cost := ManaCost.parse("{1}{G}")
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {1}{G} so %s strikes first?" % source.data.card_name, true) \
			and game.try_pay(pid, cost):
		game.continuous.add_until_eot_pump(source.id, 0, 0, [Mtg.Keyword.FIRST_STRIKE])
		game.recalculate()
		return
	for inst in _engaged_with(game, source):
		game.continuous.add_until_eot_pump(inst.id, 0, 0, [Mtg.Keyword.FIRST_STRIKE])
	game.recalculate()
