extends CardScript
## Fasting — {W} — Enchantment — (drk, uncommon)
## Oracle: At the beginning of your upkeep, put a hunger counter on this
##         enchantment. Then destroy this enchantment if it has five or more
##         hunger counters on it.
##         If you would begin your draw step, you may skip that step
##         instead. If you do, you gain 2 life.
##         When you draw a card, destroy this enchantment.
##
## Implementation: three clauses, three engine shapes.
## - The hunger clock is an upkeep trigger with counters, so five upkeeps is
##   the whole life of the card.
## - "If you would BEGIN your draw step" is a CR 614 replacement of a
##   TURN-BASED ACTION, not of a draw (CardData.draw_step_replacement): the
##   step happens not at all, so nothing draws, no DRAW_STEP fires and a
##   Howling Mine hands out nothing either. That is the difference between
##   this card and Island Sanctuary, which skips only the draw.
## - "When you draw a card" is a CARD_DRAWN trigger, and it fires on ANY
##   draw its controller makes — an Ancestral Recall ends the fast.
##
## The heuristic ALWAYS takes the fast: skipping is the reason the card is
## on the battlefield, and it is self-limiting at five turns and ten life. A
## human seat is asked — but from a turn-based action, outside any
## resolution, so the pre-flight cannot hold the question open
## (docs/ROADMAP.md, "draw replacements ask outside a resolution").


func build() -> CardData:
	return CardData.new("Fasting", "{W}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _hunger,
			"At the beginning of your upkeep, put a hunger counter on this enchantment. Then destroy it if it has five or more.",
			_yours)) \
		.replaces_draw_step(_fast) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.CARD_DRAWN, _break_the_fast,
			"When you draw a card, destroy this enchantment.",
			_you_drew)) \
		.oracle("At the beginning of your upkeep, put a hunger counter on this "
			+ "enchantment. Then destroy this enchantment if it has five or more "
			+ "hunger counters on it.\nIf you would begin your draw step, you may "
			+ "skip that step instead. If you do, you gain 2 life.\nWhen you draw a "
			+ "card, destroy this enchantment.")


static func _yours(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _you_drew(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _hunger(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.add_counters(source, "hunger", 1)
	if int(source.counters.get("hunger", 0)) >= 5:
		game.destroy(source)


static func _break_the_fast(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.destroy(source)


## The draw-step replacement: skip the step and gain 2 life.
static func _fast(game: MtgGame, source: CardInstance, pid: int) -> bool:
	if pid != source.controller_id:
		return false
	if not game.agents[pid].choose_yes_no(game, pid,
			"Skip your draw step to gain 2 life?", true):
		return false
	game.adjust_life(pid, 2)
	return true
