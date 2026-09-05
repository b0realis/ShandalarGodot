extends CardScript
## Sindbad — {1}{U} — Creature — Human — 1/1 — (4ed, uncommon)
## Oracle: {T}: Draw a card and reveal it. If it isn't a land card,
##         discard it.
##
## Implementation: a card-local effect drawing one card and, when the
## drawn card isn't a land, discarding exactly that card (the engine's
## draw appends to the end of the hand, so the drawn card is the last
## one). In a land-heavy deck it is a repeatable land tutor; in a spell
## deck it just mills.


func build() -> CardData:
	return CardData.new("Sindbad", "{1}{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human"]) \
		.activated(ActivatedAbility.new(
			"", true, [SindbadEffect.new()],
			"{T}: Draw a card and reveal it. If it isn't a land card, discard it.")) \
		.oracle("{T}: Draw a card and reveal it. If it isn't a land card, discard it.")


class SindbadEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var before := game.players[controller].hand.size()
		game.draw_cards(controller, 1)
		var hand := game.players[controller].hand
		if hand.size() <= before:
			return   # drew from an empty library
		var drawn: CardInstance = hand[-1]
		game.log_line("Sindbad reveals %s" % drawn.data.card_name)
		if not drawn.data.is_land():
			game.discard_cards(controller, [drawn])

	func describe() -> String:
		return "draw a card and reveal it; discard it unless it is a land"
