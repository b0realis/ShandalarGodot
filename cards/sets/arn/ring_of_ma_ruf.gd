extends CardScript
## Ring of Ma'rûf — {5} — Artifact — (arn, rare)
## Oracle: {5}, {T}, Exile this artifact: The next time you would draw a
##         card this turn, instead put a card you own from outside the game
##         into your hand.
##
## Implementation: a one-shot DRAW REPLACEMENT (MtgGame.replace_next_draw,
## CR 614.1a) registered as the ability resolves and consumed by the next
## draw this turn — the draw step's, a Jalum Tome's, whatever comes first
## — and dropped at cleanup. The replaced draw is not a draw at all: no
## card leaves the library, and when there is nothing outside the game to
## put into the hand the draw is still replaced, by nothing. OUTSIDE THE
## GAME is a real zone on the player (MtgPlayer.outside_the_game) — empty
## in a plain duel, and exactly where Shandalar's adventure layer (M5) will
## put the player's collection, which is what the 1997 Ring reaches into.
## The card is the controller's pick, asked with the original's own
## prompt (`@RING_OF_MARUF`, Program/promptsX1.txt:353: *"Ring of Ma'ruf:
## Select target out of play card."*).
##
## The 1997 text was the Fourth Edition one — "Skip drawing a card, remove
## Ring of Ma'rûf from the game: Put into your hand any card that you own
## but that is not in the game" (Duel.hlp) — a draw skipped in exchange
## for the card; the Oracle's replacement is that same trade, made in the
## turn's next draw.


func build() -> CardData:
	return CardData.new("Ring of Ma'rûf", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{5}", true, [WishEffect.new()],
			"{5}, {T}, Exile this artifact: The next time you would draw a card this turn, instead put a card you own from outside the game into your hand.") \
			.with_exile_cost()) \
		.oracle("{5}, {T}, Exile this artifact: The next time you would draw a card this turn, instead put a card you own from outside the game into your hand.")


class WishEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.replace_next_draw(controller, WishEffect._instead_of_the_draw)
		game.log_line("Ring of Ma'rûf waits for %s's next draw this turn"
			% game.players[controller].player_name)

	## The replaced draw: a card from outside the game into the hand.
	static func _instead_of_the_draw(game: MtgGame, pid: int,
			_ctx: Dictionary) -> void:
		var outside: Array[CardInstance] = game.players[pid].outside_the_game
		if outside.is_empty():
			game.log_line("Ring of Ma'rûf finds nothing outside the game")
			return
		var chosen := game.agents[pid].choose_card(game, pid, outside,
			"Ring of Ma'ruf: Select target out of play card.")
		if chosen == null or not outside.has(chosen):
			chosen = outside[0]
		game.take_from_outside_the_game(chosen, pid)

	func describe() -> String:
		return "your next draw this turn puts a card you own from outside the game into your hand"
