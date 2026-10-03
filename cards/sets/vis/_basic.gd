extends RefCounted
## Visions (_basic, Pack 8). Vanilla and keyword-only creatures and lands: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Freewind Falcon", "Longbow Archer", "Phyrexian Walker": pass
		"Scalebane's Elite", "Tempest Drake", "Warthog": pass
		_: return false
	return true
