extends CardScript
## Gravity Sphere — {2}{R} — World Enchantment — (leg, rare)
## Oracle: All creatures lose flying.
##
## Implementation: a global static that erases FLYING from every creature
## on every recalculation — a CR 613 LAYER 6 effect, so it is marked
## `changing_abilities()` and applied in timestamp order with every other
## grant and loss (CR 613.7). It strips the flying an Aura granted BEFORE
## it entered (a Flight already on the table), and a Flight cast AFTER it
## puts the wings back, which is the printed rule and was not what this
## card did until 2026-09-11. A WORLD permanent (CR 704.5k).


func build() -> CardData:
	return CardData.new("Gravity Sphere", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(_apply, "All creatures lose flying.") \
			.changing_abilities()) \
		.oracle("All creatures lose flying.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_keywords.erase(Mtg.Keyword.FLYING)
