extends CardScript
## Stasis — {1}{U} — Enchantment — (2ed, rare)
## Oracle: Players skip their untap steps.
##         At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay {U}.
##
## Implementation: the untap ban is a static that raises cur_skips_untap on
## every permanent in play, both sides — so the untap step still clears
## summoning sickness and resets land drops, it just untaps nothing. The
## rent is the engine's usual "unless you pay" trigger: floating mana
## first, then auto-tapped lands.
##
## The rent is a real QUESTION, asked of the paying seat through its own
## DecisionAgent: the human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The `hint` below is
## only the default answer, not a decision the engine takes.


func build() -> CardData:
	return CardData.new("Stasis", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_freeze, "Players skip their untap steps.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, sacrifice this enchantment unless you pay {U}.",
			_your_upkeep)) \
		.oracle("Players skip their untap steps.\nAt the beginning of your upkeep, sacrifice this enchantment unless you pay {U}.")


static func _freeze(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		inst.cur_skips_untap = true


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _pay_the_rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var rent := ManaCost.parse("{U}")
	var pid := source.controller_id
	if game.can_afford_cost(pid, rent) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {U} to keep Stasis?", true) and game.try_pay(pid, rent):
		return
	game.sacrifice_permanent(source)
