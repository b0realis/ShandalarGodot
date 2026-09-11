extends CardScript
## Goblin King — {1}{R}{R} — Creature — Goblin — 2/2 (2ed, rare)
## Oracle: Other Goblins get +1/+1 and have mountainwalk.
##
## Implementation: tribal lord, red flavor — see lord_of_atlantis.gd for
## the pattern notes (this is its mirror with goblins and mountainwalk).


func build() -> CardData:
	return CardData.new("Goblin King", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["goblin"]) \
		.static_ability(StaticAbility.new(
			_apply, "Other Goblins get +1/+1.")) \
		.static_ability(StaticAbility.new(
			_walk, "Other Goblins have mountainwalk.").changing_abilities()) \
		.oracle("Other Goblins get +1/+1 and have mountainwalk.")


## TWO STATICS, one per CR 613 layer (613.1) — see lord_of_atlantis.gd.
static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature() and inst.has_subtype("goblin"):
			inst.cur_power += 1
			inst.cur_toughness += 1


static func _walk(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst != source and inst.is_creature() and inst.has_subtype("goblin") \
				and not inst.cur_landwalk.has("mountain"):
			inst.cur_landwalk.append("mountain")
