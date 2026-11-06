extends RefCounted
## Urza's Legacy (_choices, Pack 10). Modal spells: Parch.
##
## Parch is a real "Choose one —" (CR 700.2): the mode is chosen as it is
## cast, with each mode's own target (CardData.mode, Healing Salve's
## shape, 2ed/healing_salve.gd) — "target blue creature" reads the live
## color (CR 105.2). The AI's mode picker reads the public board: the
## four-damage mode for an opposing blue creature the two would not kill.
## tests/cards/test_pack_10_B2_choices.gd pins it.


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Parch":
			var blue := DamageEffect.new(4).target_creature("target blue creature", _blue)
			blue.target_spec.because(TargetSpec.WHY["color"])
			c.mode("Parch deals 2 damage to any target", [DamageEffect.new(2).any_target()])
			c.mode("Parch deals 4 damage to target blue creature", [blue])
			c.with_ai_mode(_parch_mode)
		_: return false
	return true


static func _blue(i: CardInstance) -> bool:
	return i.has_color(Mtg.ManaColor.U)


## 1 when an opposing blue creature survives two damage but not four
## (live toughness less damage already marked), else 0.
static func _parch_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].creatures():
		if not g.is_present(i) or not _blue(i):
			continue
		var left := i.cur_toughness - i.damage
		if left > 2 and left <= 4:
			return 1
	return 0
