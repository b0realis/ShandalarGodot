extends RefCounted
## Urza's Destiny (_cycling, Pack 10). Cycling cards and "when you cycle" cards.
##
## CYCLING (CR 702.29a) is [method CardData.with_cycling] (Pack 10 engine
## package E2), appended after each card's own text — see
## cards/sets/usg/_cycling.gd for the mechanism.
##
## - Fend Off: "Prevent all combat damage that would be dealt by target
##   creature this turn" (PreventCombatDamageEffect's targeted form — a
##   prevention effect, so it is legal in the 1997 damage-prevention window).
## - Rapid Decay: Ebony Charm's graveyard mode — up to three target cards
##   from a single graveyard, zero included (mir/_spells.gd GraveExile).
## - Flame Jet: 3 damage to target player (there are no planeswalkers).
##
## tests/cards/test_pack_10_B11_cycling.gd (every card's cycling) and
## test_pack_10_B11_ulg_uds.gd (each card's own text) pin each card.
const MS := preload("res://cards/sets/mir/_spells.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Fend Off":
			c.spell(PreventCombatDamageEffect.new().by_target_creature())
		"Rapid Decay":
			c.spell(MS.GraveExile.new())
		"Flame Jet":
			c.spell(DamageEffect.new(3).target_player())
		_: return false
	c.with_cycling()
	return true
