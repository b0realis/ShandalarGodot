extends CardScript
## Field of Dreams — {U} — World Enchantment — (leg, rare)
## Oracle: Players play with the top card of their libraries revealed.
##
## Implementation: a static that marks BOTH players' library tops as
## public (MtgPlayer.top_card_revealed, rebuilt by the continuous
## pipeline so it ends the moment the enchantment leaves). The engine
## exposes the card through MtgGame.revealed_top_card(pid) — the one read
## for the duel screen and the AI — and logs each new top as state is
## published ("The top card of X's library is revealed: Y"), so a draw, a
## shuffle or a Millstone that turns a new card up is a matter of record
## for both seats. Its WORLD supertype makes it police (and be policed
## by) the other Legends world enchantments (CR 704.5k).
##
## The 1997 game showed the top card as a named marker beside each
## library (Manalink's `card_field_of_dreams`, a "card name legacy" per
## player, refreshed whenever a library went from empty to non-empty);
## the log line here is that marker's equivalent.


func build() -> CardData:
	return CardData.new("Field of Dreams", "{U}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(_reveal_tops,
			"Players play with the top card of their libraries revealed.")) \
		.oracle("Players play with the top card of their libraries revealed.")


static func _reveal_tops(game: MtgGame, _source: CardInstance) -> void:
	for p in game.players:
		p.top_card_revealed = true
