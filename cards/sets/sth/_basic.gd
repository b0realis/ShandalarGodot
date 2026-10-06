extends RefCounted
## Stronghold (_basic, Pack 9). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Skyshroud Falcon", "Wall of Razors", "Youthful Knight": pass
		_: return false
	return true
