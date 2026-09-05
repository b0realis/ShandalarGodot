extends CardScript
## Bad Moon — {1}{B} — Enchantment (2ed, rare)
## Oracle: Black creatures get +1/+1.
##
## Implementation: global static ability boosting every black creature on
## the battlefield, both players' — symmetric as printed. Mirror twin of
## crusade.gd; see that file for the pattern notes.


func build() -> CardData:
	return CardData.new("Bad Moon", "{1}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_apply, "Black creatures get +1/+1.")) \
		.oracle("Black creatures get +1/+1.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.B):
			inst.cur_power += 1
			inst.cur_toughness += 1
