extends CardScript
## Blood Moon — {2}{R} — Enchantment — (drk, rare)
## Oracle: Nonbasic lands are Mountains.
##
## Implementation: a global static calling become_basic_land_type on every
## NONBASIC land — live subtypes become ["mountain"] and live mana
## abilities become "{T}: Add {R}", so dual lands, Mishra's Factory,
## Library of Alexandria and every utility land in the pool are reduced to
## red mana and nothing else. Basic lands (Supertype.BASIC) are untouched,
## and so are the abilities of nonland permanents.


func build() -> CardData:
	return CardData.new("Blood Moon", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_apply, "Nonbasic lands are Mountains.") \
			.changing_land_types()) \
		.oracle("Nonbasic lands are Mountains.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_land() and (inst.data.supertypes & Mtg.Supertype.BASIC) == 0:
			inst.become_basic_land_type("mountain", Mtg.ManaColor.R)
