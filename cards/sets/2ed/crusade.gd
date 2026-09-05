extends CardScript
## Crusade — {W}{W} — Enchantment (2ed, rare)
## Oracle: White creatures get +1/+1.
##
## Implementation: a GLOBAL static ability — the apply callable runs on
## every recalculation and boosts every white creature on the battlefield,
## BOTH players' (as printed; the original Shandalar dungeons famously
## weaponize this symmetry — see the lore doc's dungeon notes).
## Mirror twin of bad_moon.gd.


func build() -> CardData:
	return CardData.new("Crusade", "{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_apply, "White creatures get +1/+1.")) \
		.oracle("White creatures get +1/+1.")


static func _apply(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature() and (inst.cur_colors & Mtg.ManaColor.W):
			inst.cur_power += 1
			inst.cur_toughness += 1
