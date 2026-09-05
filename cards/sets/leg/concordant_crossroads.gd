extends CardScript
## Concordant Crossroads — {G} — World Enchantment — (leg, rare)
## Oracle: All creatures have haste.
##
## Implementation: a global static granting HASTE to every creature on the
## battlefield, both players'. WORLD supertype, so it and any other world
## permanent police each other through the world rule (CR 704.5k) — the
## newest survives. One green mana for the fastest board in the pool.


func build() -> CardData:
	return CardData.new("Concordant Crossroads", "{G}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.static_ability(StaticAbility.new(_apply, "All creatures have haste.")) \
		.oracle("All creatures have haste.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and not inst.cur_keywords.has(Mtg.Keyword.HASTE):
			inst.cur_keywords.append(Mtg.Keyword.HASTE)
