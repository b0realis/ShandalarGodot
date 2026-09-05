extends CardScript
## Gosta Dirk — {3}{W}{W}{U}{U} — Legendary Creature — Human Warrior — 4/4 — (leg, rare)
## Oracle: First strike
##         Creatures with islandwalk can be blocked as though they didn't
##         have islandwalk.
##
## Implementation: printed first strike plus Undertow's static on a body —
## it adds "island" to MtgGame.nullified_landwalk while it is on the
## battlefield. Aimed squarely at the blue decks the rest of his colours
## belong to.


func build() -> CardData:
	return CardData.new("Gosta Dirk", "{3}{W}{W}{U}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "warrior"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with islandwalk can be blocked as though they didn't have "
			+ "islandwalk.")) \
		.oracle("First strike\nCreatures with islandwalk can be blocked as though "
			+ "they didn't have islandwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["island"] = true
