extends RefCounted
## Urza's Destiny (_combat, Pack 10). Combat restrictions, requirements and combat-damage effects.
##
## - Wall of Glare is the pool's first PRINTED "can block any number of
##   creatures" (CR 509.1b): CardData.with_extra_blocks(-1), read live as
##   CardInstance.cur_extra_blocks by MtgGame.blocks_allowed — the
##   permission Blaze of Glory grants for a turn and Two-Headed Giant of
##   Foriys prints as one more. Defender is the scaffold's.
## - Thorn Elemental: "you may have this creature assign its combat damage
##   as though it weren't blocked" is Lone Wolf's static
##   (cards/sets/p02/_combat_mana.gd `_bypass`): a blocked Elemental's
##   controller is offered the defending player as the whole assignment
##   (the damage request's `special: "bypass"`, CR 510.1c), or assigns to
##   its blockers as usual; the blockers deal their damage either way.
## tests/cards/test_pack_10_B4_white_blue.gd, _green.gd and
## _glare_picker.gd (the human block gesture) pin both.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Wall of Glare":
			c.with_extra_blocks(-1)
		"Thorn Elemental":
			c.static_ability(StaticAbility.new(_bypass,
				"You may have this creature assign its combat damage as though it weren't blocked."))
		_: return false
	return true


static func _bypass(_g: MtgGame, s: CardInstance) -> void:
	s.cur_damage_as_unblocked = true
