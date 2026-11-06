extends RefCounted
## Urza's Legacy (_basic, Pack 10). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Defender of Chaos", "Defender of Law", "Giant Cockroach", "Plague Beetle", "Weatherseed Faeries", "Yavimaya Wurm": pass
		_: return false
	return true
