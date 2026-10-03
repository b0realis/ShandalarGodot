extends RefCounted
## Mirage (_basic, Pack 8). Vanilla and keyword-only creatures and lands: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets, or the one
## keyword the generator could not emit, set here (rampage N — CR 702.23,
## [member CardData.rampage], applied by the combat code).

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Bay Falcon", "Blistering Barrier", "Cerulean Wyvern": pass
		"Crash of Rhinos", "Ekundu Griffin", "Femeref Scouts": pass
		"Giant Mantis", "Hazerider Drake", "Iron Tusk Elephant": pass
		"Karoo Meerkat", "Melesse Spirit", "Noble Elephant": pass
		"Talruum Minotaur", "Teremko Griffin", "Viashino Warrior": pass
		"Wild Elephant", "Windreaper Falcon": pass
		"Horrible Hordes": c.with_rampage(1)
		"Teeka's Dragon": c.with_rampage(4)
		_: return false
	return true
