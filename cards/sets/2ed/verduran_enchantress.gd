extends CardScript
## Verduran Enchantress — {1}{G}{G} — Creature — Human Druid — 0/2 (2ed, rare)
## Oracle: Whenever you cast an enchantment spell, you may draw a card.
##
## Implementation: a SPELL_CAST trigger filtered to the controller's own
## enchantment casts. The "you may" is a real question for the controller's
## seat, with "yes" as the hint because declining is almost never right.
## The engine that powers every enchantress deck since 1993 — and the
## dos486 guide's note that the AI's Enchantress "summons a Summoner"
## refers to the enemy wizard, not this card, which now works properly.


func build() -> CardData:
	return CardData.new("Verduran Enchantress", "{1}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 2) \
		.with_subtypes(["human", "druid"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SPELL_CAST, _inspire,
			"Whenever you cast an enchantment spell, you may draw a card.",
			_my_enchantment)) \
		.oracle("Whenever you cast an enchantment spell, you may draw a card.")


static func _my_enchantment(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["controller"] == source.controller_id \
		and event.data["instance"].data.is_type(Mtg.CardType.ENCHANTMENT)


static func _inspire(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# "You MAY draw a card" — asked, with "yes" as the hint, because
	# declining is almost never right (docs/adding-cards.md: a "you may"
	# must be declinable through the controller's agent).
	var pid := source.controller_id
	if game.agents[pid].choose_yes_no(game, pid,
			"Draw a card from %s?" % source.data.card_name, true):
		game.draw_cards(pid, 1)
