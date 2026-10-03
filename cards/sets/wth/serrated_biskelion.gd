extends CardScript
## Serrated Biskelion — {3} — Artifact Creature — Construct (uncommon, wth).
## Oracle: {T}: Put a -1/-1 counter on this creature and a -1/-1 counter on target creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serrated Biskelion", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 2)
	c.with_subtypes(["construct"])
	c.oracle("{T}: Put a -1/-1 counter on this creature and a -1/-1 counter on target creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
