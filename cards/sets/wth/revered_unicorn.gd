extends CardScript
## Revered Unicorn — {1}{W} — Creature — Unicorn (uncommon, wth).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         When this creature leaves the battlefield, you gain life equal to the number of age counters on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Revered Unicorn", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["unicorn"])
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nWhen this creature leaves the battlefield, you gain life equal to the number of age counters on it.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
