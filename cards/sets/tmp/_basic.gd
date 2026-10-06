extends RefCounted
## Tempest (_basic, Pack 9). Vanilla and keyword-only creatures: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bayou Dragonfly", "Benthic Behemoth", "Canopy Spider": pass
		"Canyon Wildcat", "Coiled Tinviper", "Fighting Drake": pass
		"Heartwood Treefolk", "Lightning Elemental", "Lowland Giant": pass
		"Metallic Sliver", "Phyrexian Hulk", "Rootbreaker Wurm": pass
		"Sky Spirit", "Trained Armodon": pass
		_: return false
	return true
