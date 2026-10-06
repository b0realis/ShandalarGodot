extends CardScript
## Spined Sliver — {R}{G} — Creature — Sliver (uncommon, sth).
## Oracle: Whenever a Sliver becomes blocked, that Sliver gets +1/+1 until end of turn for each creature blocking it.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spined Sliver", "{R}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("Whenever a Sliver becomes blocked, that Sliver gets +1/+1 until end of turn for each creature blocking it.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
