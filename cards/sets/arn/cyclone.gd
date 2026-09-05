extends CardScript
## Cyclone — {2}{G}{G} — Enchantment — (arn, uncommon)
## Oracle: At the beginning of your upkeep, put a wind counter on this
##         enchantment, then sacrifice this enchantment unless you pay {G}
##         for each wind counter on it. If you pay, this enchantment deals
##         damage equal to the number of wind counters on it to each
##         creature and each player.
##
## Implementation: the counter goes on FIRST, so the very first upkeep
## already costs {G} and already deals 1 — the storm never arrives free.
## The rent uses the engine's mid-trigger payment (floating mana, then
## auto-tapped lands) and the sweep is DamageAllEffect's "each creature and
## each player", which includes the Cyclone's own controller: this is a
## symmetrical clock, and letting it run is a real decision.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


func build() -> CardData:
	return CardData.new("Cyclone", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _blow,
			"At the beginning of your upkeep, put a wind counter on this enchantment, then sacrifice it unless you pay {G} for each wind counter on it. If you pay, it deals that much damage to each creature and each player.",
			_own_upkeep)) \
		.oracle("At the beginning of your upkeep, put a wind counter on this enchantment, "
			+ "then sacrifice this enchantment unless you pay {G} for each wind counter on "
			+ "it. If you pay, this enchantment deals damage equal to the number of wind "
			+ "counters on it to each creature and each player.")


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _blow(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return   # nothing left to put a counter on, or to sacrifice
	game.add_counters(source, "wind", 1)
	var winds := int(source.counters.get("wind", 0))
	var pid := source.controller_id
	var cost := ManaCost.parse("{G}".repeat(winds))
	# The HINT for a seat that answers with the default: pay while it is
	# affordable and the storm would not blow its own controller away.
	var hint: bool = game.players[pid].life > winds
	if game.can_afford_cost(pid, cost) \
			and game.agents[pid].choose_yes_no(game, pid,
				"Pay %d green to keep Cyclone?" % winds, hint) \
			and game.try_pay(pid, cost):
		DamageAllEffect.new(winds).and_each_player().resolve(
			game, source, pid, null)
		return
	game.sacrifice_permanent(source)
