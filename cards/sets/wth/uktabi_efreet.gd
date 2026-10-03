extends CardScript
## Uktabi Efreet — {2}{G}{G} — Creature — Efreet (common, wth).
## Oracle: Cumulative upkeep {G} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Uktabi Efreet", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["efreet"])
	c.oracle("Cumulative upkeep {G} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
