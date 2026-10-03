extends CardScript
## Mwonvuli Ooze — {G} — Creature — Ooze (rare, wth).
## Oracle: Cumulative upkeep {2} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay {2} for each age counter on it.)
##         Mwonvuli Ooze's power and toughness are each equal to 1 plus twice the number of age counters on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mwonvuli Ooze", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["ooze"])
	c.oracle("Cumulative upkeep {2} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay {2} for each age counter on it.)\nMwonvuli Ooze's power and toughness are each equal to 1 plus twice the number of age counters on it.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
