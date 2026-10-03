extends CardScript
## Sea Scryer — {1}{U} — Creature — Merfolk Wizard (common, mir).
## Oracle: {T}: Add {C}.
##         {1}, {T}: Add {U}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sea Scryer", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk","wizard"])
	c.oracle("{T}: Add {C}.\n{1}, {T}: Add {U}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
