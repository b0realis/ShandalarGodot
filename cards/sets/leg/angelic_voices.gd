extends CardScript
## Angelic Voices — {2}{W}{W} — Enchantment — (leg, rare)
## Oracle: Creatures you control get +1/+1 as long as you control no
##         nonartifact, nonwhite creatures.
##
## Implementation: a conditional one-sided anthem. The condition is
## re-evaluated on every recalculation, so the choir falls silent the
## instant a green creature joins your board and starts again when it
## leaves. Colour reads the printed mana cost (pool-wide convention).


func build() -> CardData:
	return CardData.new("Angelic Voices", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Creatures you control get +1/+1 as long as you control no nonartifact, "
			+ "nonwhite creatures.")) \
		.oracle("Creatures you control get +1/+1 as long as you control no nonartifact, "
			+ "nonwhite creatures.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var mine: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst.controller_id == source.controller_id and inst.is_creature():
			if not inst.is_type(Mtg.CardType.ARTIFACT) \
					and (inst.cur_colors & Mtg.ManaColor.W) == 0:
				return   # a nonartifact, nonwhite creature silences the choir
			mine.append(inst)
	for inst in mine:
		inst.cur_power += 1
		inst.cur_toughness += 1
