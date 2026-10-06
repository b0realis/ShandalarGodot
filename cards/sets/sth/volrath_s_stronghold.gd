extends CardScript
## Volrath's Stronghold —  — Legendary Land (rare, sth).
## Oracle: {T}: Add {C}.
##         {1}{B}, {T}: Put target creature card from your graveyard on top of your library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Stronghold", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("{T}: Add {C}.\n{1}{B}, {T}: Put target creature card from your graveyard on top of your library.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
