extends RefCounted
## Weatherlight (_basic, Pack 8). Vanilla and keyword-only creatures and lands: nothing beyond the printed characteristics the card file sets.
## Listed names are complete: their whole Oracle text is printed
## characteristics and keywords the card file already sets, or the one
## keyword the generator could not emit, set here ("attacks each combat if
## able" is Mtg.Keyword.MUST_ATTACK, enforced by declare_attackers — the
## Juggernaut shape).

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Benalish Infantry", "Duskrider Falcon", "Razortooth Rats": pass
		"Bloodrock Cyclops": c.with_keywords([Mtg.Keyword.MUST_ATTACK])
		_: return false
	return true
