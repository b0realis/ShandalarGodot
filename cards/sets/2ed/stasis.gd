extends CardScript
## Stasis — {1}{U} — Enchantment — (2ed, rare)
## Oracle: Players skip their untap steps.
##         At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay {U}.
##
## Implementation: a static raising the engine's real untap-step SKIP for
## every player (MtgPlayer.skips_untap_step, Sands of Time's): the step is
## replaced away (CR 614.10) — nothing untaps, nothing phases, "until your
## next untap step" effects and the one-shot "doesn't untap during its
## controller's next untap step" locks wait for the first step that really
## happens — while the turn itself still begins (summoning sickness ends,
## the land drop resets; MtgGame._run_untap_step). The rent is the
## engine's usual "unless you pay" trigger: floating mana first, then
## auto-tapped mana sources (every source, not only lands, since
## 2026-09-11).
##
## Until the bug hunt of 2026-10-21 it only froze every permanent
## (cur_skips_untap) and let each untap step run — spending a Barl's
## Cage's lock on a step that untapped nothing. The freeze flags are still
## raised: the AI's lock reader and the duel screen read them.
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
	for p in game.players:
		p.skips_untap_step = true
	for inst in game.all_battlefield():
		inst.cur_skips_untap = true


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _pay_the_rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var rent := ManaCost.parse("{U}")
	var pid := source.controller_id
	if EffectBase.unless_paid(game, pid, rent, "Pay {U} to keep Stasis?"):
		return
	game.sacrifice_permanent(source)
