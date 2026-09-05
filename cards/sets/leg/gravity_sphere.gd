extends CardScript
## Gravity Sphere — {2}{R} — World Enchantment — (leg, rare)
## Oracle: All creatures lose flying.
##
## Implementation: a global static that erases FLYING from every creature
## on every recalculation. Because statics run after the reset, this also
## strips flying an aura granted (Flight) — the printed behavior. A WORLD
## permanent (CR 704.5k).


func build() -> CardData:
	return CardData.new("Gravity Sphere", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(_apply, "All creatures lose flying.")) \
		.oracle("All creatures lose flying.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_keywords.erase(Mtg.Keyword.FLYING)
