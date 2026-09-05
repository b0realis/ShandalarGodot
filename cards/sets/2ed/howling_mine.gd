extends CardScript
## Howling Mine — {2} — Artifact (2ed, rare)
## Oracle: At the beginning of each player's draw step, if this artifact is
##         untapped, that player draws an additional card.
##
## Implementation: DRAW_STEP trigger (dispatched after the normal draw)
## with an untapped-source condition, drawing one more for the event's
## player. Symmetric card advantage — both players feast, which is the
## card's whole gamble.


func build() -> CardData:
	return CardData.new("Howling Mine", "{2}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DRAW_STEP,
			_extra_draw,
			"At the beginning of each player's draw step, if this artifact is untapped, that player draws an additional card.",
			_untapped)) \
		.oracle("At the beginning of each player's draw step, if this artifact is untapped, that player draws an additional card.")


static func _untapped(_game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return not source.tapped


## CR 603.4 — an intervening "if" is checked BOTH when the ability would
## trigger and again as it resolves, so tapping the Mine in response (Icy
## Manipulator, Relic Barrier) really does stop the extra card. Land Tax
## (`4ed/land_tax.gd`) is the same shape.
static func _extra_draw(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.tapped:
		game.log_line("Howling Mine is tapped — no extra card")
		return
	game.draw_cards(event.data["player"], 1)
