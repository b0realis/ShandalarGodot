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
			_apply, "Other Goblins get +1/+1 and have mountainwalk.")) \
		.oracle("Other Goblins get +1/+1 and have mountainwalk.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst == source or not inst.is_creature():
			continue
		if inst.has_subtype("goblin"):
			inst.cur_power += 1
			inst.cur_toughness += 1
			if not inst.cur_landwalk.has("mountain"):
				inst.cur_landwalk.append("mountain")
