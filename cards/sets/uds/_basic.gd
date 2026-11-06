extends RefCounted
## Urza's Destiny (_basic, Pack 10). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Goblin Berserker", "Goliath Beetle", "Plated Spider", "Squirming Mass", "Tormented Angel", "Voice of Duty", "Voice of Reason", "Wild Colos": pass
		_: return false
	return true
