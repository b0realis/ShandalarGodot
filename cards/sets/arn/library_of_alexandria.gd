extends CardScript
## Library of Alexandria — Land — (arn, uncommon)
## Oracle: {T}: Add {C}.
##         {T}: Draw a card. Activate only if you have exactly seven cards
##         in hand.
##
## Implementation: both halves of the most famous land in the game — a
## colourless mana ability and a draw gated on the exact hand size, which
## the engine checks at activation (ActivatedAbility.only_if).


func build() -> CardData:
	return CardData.new("Library of Alexandria", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.activated(ActivatedAbility.new("", true, [DrawEffect.new(1)],
			"{T}: Draw a card. Activate only if you have exactly seven cards in hand.") \
			.only_if(_exactly_seven)) \
		.oracle("{T}: Add {C}.\n{T}: Draw a card. Activate only if you have exactly seven cards in hand.")


static func _exactly_seven(game: MtgGame, source: CardInstance) -> String:
	if game.players[source.controller_id].hand.size() != 7:
		return "activate only with exactly seven cards in hand"
	return ""
