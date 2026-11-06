extends RefCounted
## Urza's Destiny (_untap, Pack 10). Spells and abilities that untap lands or
## permanents, on Urza's Saga's shared pieces (cards/sets/usg/_untap.gd).
##
## - Blizzard Elemental: "{3}{U}: Untap this creature" (untap_self_ability).
## - Treachery: an Aura kept here for its distinguishing clause — Control
##   Magic's steal (CardData.steals_control: the creature comes under your
##   control as the Aura attaches and goes home when it leaves) and "When
##   this Aura enters, untap up to five lands", which resolves for
##   Treachery's controller even if the Aura has gone (CR 603.6).
##
## tests/cards/test_pack_10_B9_untap_up_to.gd and test_pack_10_B9_untap.gd
## pin each card.
const U := preload("res://cards/sets/usg/_untap.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Blizzard Elemental":
			c.activated(U.untap_self_ability("{3}{U}", "{3}{U}: Untap this creature."))
		"Treachery":
			c.enchants(TargetSpec.creature()).steals_control()
			c.triggered(U.enters_untapping(5, "When this Aura enters, untap up to five lands."))
		_: return false
	return true
