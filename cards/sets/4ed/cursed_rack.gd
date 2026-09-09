extends CardScript
## Cursed Rack — {4} — Artifact — (4ed, uncommon)
## Oracle: As this artifact enters, choose an opponent.
##         The chosen player's maximum hand size is four.
##
## Implementation: a CR 614.1c REPLACEMENT (CardData.as_it_enters)
## remembering the chosen opponent in the Rack's card-local memory (in a
## duel there is exactly one, so the choice makes itself) plus a static
## writing that player's MtgPlayer.max_hand_size, which the cleanup step
## enforces.
##
## IT USED TO BE AN ARRIVAL TRIGGER (fixed 2026-09-09, with Lich, Jihad,
## Black Vise and The Rack). A trigger is a stack object, so an Aladdin
## activated IN THAT WINDOW took the Rack before the choice was stamped:
## the stamp was then made from the thief's seat and named the Rack's own
## caster, who spent the rest of the game discarding to four. Made as it
## enters, the choice is out of reach of anything that could respond.


func build() -> CardData:
	return CardData.new("Cursed Rack", "{4}", Mtg.CardType.ARTIFACT) \
		.as_it_enters(_choose) \
		.static_ability(StaticAbility.new(
			_apply, "The chosen player's maximum hand size is four.")) \
		.oracle("As this artifact enters, choose an opponent.\nThe chosen player's "
			+ "maximum hand size is four.")


## THE CHOICE (CR 614.1c), made as the Rack arrives and never afterwards;
## MtgGame._put_on_battlefield recalculates straight afterwards, which is
## what publishes it to the static below.
static func _choose(game: MtgGame, source: CardInstance, controller: int) -> void:
	source.memory["victim"] = game.opponent_of(controller)


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var victim: int = int(source.memory.get("victim",
		game.opponent_of(source.controller_id)))
	game.players[victim].max_hand_size = 4
