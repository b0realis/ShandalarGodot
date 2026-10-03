extends CardScript
## Vodalian Illusionist — {2}{U} — Creature — Merfolk Wizard (uncommon, wth).
## Oracle: {U}{U}, {T}: Target creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vodalian Illusionist", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["merfolk","wizard"])
	c.oracle("{U}{U}, {T}: Target creature phases out. (While it's phased out, it's treated as though it doesn't exist. It phases in before its controller untaps during their next untap step.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
