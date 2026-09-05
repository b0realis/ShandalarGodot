extends CardScript
## Primordial Ooze — {R} — Creature — Ooze — 1/1 — (leg, uncommon)
## Oracle: This creature attacks each combat if able.
##         At the beginning of your upkeep, put a +1/+1 counter on this
##         creature. Then you may pay {X}, where X is the number of +1/+1
##         counters on it. If you don't, tap this creature and it deals X
##         damage to you.
##
## Implementation: a one-mana creature that grows every upkeep and charges
## you rent for the privilege. The counter goes on FIRST, so the rent is
## always the NEW size — a 2/2 on your next upkeep already costs {1}. The
## +1/+1 counter is a plain named counter; ContinuousEffects parses the
## name and moves P/T, so the Ooze needs no static of its own.
##
## Not paying taps it, which is also what excuses it from its own "attacks
## each combat if able" (CR 508.1d: a requirement is obeyed only as far as
## the restrictions allow, and a tapped creature cannot attack).
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


func build() -> CardData:
	return CardData.new("Primordial Ooze", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["ooze"]) \
		.with_keywords([Mtg.Keyword.MUST_ATTACK]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _grow,
			"At the beginning of your upkeep, put a +1/+1 counter on this creature. Then you may pay {X}, where X is the number of +1/+1 counters on it. If you don't, tap this creature and it deals X damage to you.",
			_own_upkeep)) \
		.oracle("This creature attacks each combat if able.\n"
			+ "At the beginning of your upkeep, put a +1/+1 counter on this creature. Then "
			+ "you may pay {X}, where X is the number of +1/+1 counters on it. If you don't, "
			+ "tap this creature and it deals X damage to you.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _grow(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.add_counters(source, "+1/+1", 1)
	var x := int(source.counters.get("+1/+1", 0))
	var pid := int(event.data["player"])
	var cost := ManaCost.parse("{%d}" % x)
	# The HINT: keep paying while the rent is small, or while the damage is
	# a real share of the life total.
	var hint: bool = x <= 3 or game.players[pid].life <= x * 2
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay {%d} to keep %s active?" % [x, source.data.card_name], hint) \
			and game.try_pay(pid, cost):
		return
	game.tap_permanent(source)
	game.deal_damage(source, TargetRef.player(pid), x)
