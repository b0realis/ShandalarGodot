extends CardScript
## Library of Leng — {1} — Artifact — (2ed, uncommon)
## Oracle: You have no maximum hand size.
##         If an effect causes you to discard a card, discard it, but you
##         may put it on top of your library instead of into your graveyard.
##
## Implementation: both halves are player flags the continuous pipeline
## rebuilds every pass — MtgPlayer.max_hand_size out of reach, and
## MtgPlayer.discard_to_library_top, which MtgGame.discard_cards /
## discard_random / discard_hand honour for an EFFECT's discard: the
## discarder is asked, card by card, "Library of Leng: Put <name> on top
## of your library instead of into your graveyard?" (hint: yes for a
## spell, no for a land). The 1997 help's rulings on the card draw the
## line and the engine follows them: a discard an effect requires as it
## resolves qualifies "even if you played the effect" (Sindbad, Wheel of
## Fortune — the Library + Wheel trick keeps a hand), a discard paid as a
## COST does not (Land's Edge, Jandor's Ring), and "you are still
## discarding, just to your library" — Psychic Purge's discard trigger
## fires either way. The cleanup step's hand-size discard is a turn-based
## action, not an effect, and with no maximum hand size never happens.


func build() -> CardData:
	return CardData.new("Library of Leng", "{1}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_no_limit,
			"You have no maximum hand size. If an effect causes you to discard a card, you may put it on top of your library instead.")) \
		.oracle("You have no maximum hand size.\nIf an effect causes you to discard a card, discard it, but you may put it on top of your library instead of into your graveyard.")


static func _no_limit(game: MtgGame, source: CardInstance) -> void:
	game.players[source.controller_id].max_hand_size = 999
	game.players[source.controller_id].discard_to_library_top = true
