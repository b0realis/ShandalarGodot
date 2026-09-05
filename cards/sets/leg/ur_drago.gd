extends CardScript
## Ur-Drago — {3}{U}{U}{B}{B} — Legendary Creature — Elemental — 4/4 — (leg, rare)
## Oracle: First strike
##         Creatures with swampwalk can be blocked as though they didn't
##         have swampwalk.
##
## Implementation: Gosta Dirk's shape in blue-black — first strike plus a
## static adding "swamp" to MtgGame.nullified_landwalk. The natural answer
## to a Bog Wraith or a Zombie Master's tribe.


func build() -> CardData:
	return CardData.new("Ur-Drago", "{3}{U}{U}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["elemental"]) \
		.with_keywords([Mtg.Keyword.FIRST_STRIKE]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures with swampwalk can be blocked as though they didn't have "
			+ "swampwalk.")) \
		.oracle("First strike\nCreatures with swampwalk can be blocked as though "
			+ "they didn't have swampwalk.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	game.nullified_landwalk["swamp"] = true
