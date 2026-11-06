extends RefCounted
## Urza's Saga (_basic, Pack 10). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Argothian Swine", "Blanchwood Treefolk", "Coral Merfolk", "Crazed Skirge", "Goblin Spelunkers", "Guma", "Pegasus Charger", "Serra Zealot", "Thundering Giant", "Voice of Grace", "Voice of Law": pass
		_: return false
	return true
