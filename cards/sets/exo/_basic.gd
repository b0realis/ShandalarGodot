extends RefCounted
## Exodus (_basic, Pack 9). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets — Paladin
## en-Vec's first strike and its one protection keyword naming black and
## red (a single colour mask, CR 702.16) included; Mirri, Cat Warrior's
## legendary supertype is printed too (the 1997 legend rule applies).
## tests/cards/test_pack_9_B11_lands_basic.gd pins the four.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Mirri, Cat Warrior", "Paladin en-Vec", "Sabertooth Wyvern": pass
		"Standing Troops": pass
		_: return false
	return true
