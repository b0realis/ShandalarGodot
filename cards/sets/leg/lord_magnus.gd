extends CardScript
## Lord Magnus — {3}{G}{W}{W} — Legendary Creature — Human Druid — 4/3 — (leg, uncommon)
## Oracle: First strike
##         Creatures with plainswalk can be blocked as though they didn't
##         have plainswalk.
##         Creatures with forestwalk can be blocked as though they didn't
##         have forestwalk.
##
## Implementation: the double nullifier — one static adding BOTH "plains"
## and "forest" to MtgGame.nullified_landwalk, plus printed first strike.
## Exactly the two colours he is made of, which is the joke.


func build() -> CardData:
	return CardData.new("Lord Magnus", "{3}{G}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(4, 3) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "druid"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with plainswalk or forestwalk can be blocked as though they "
			+ "didn't have it.")) \
		.oracle("First strike\nCreatures with plainswalk can be blocked as though "
			+ "they didn't have plainswalk.\nCreatures with forestwalk can be blocked "
			+ "as though they didn't have forestwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["plains"] = true
	game.nullified_landwalk["forest"] = true
