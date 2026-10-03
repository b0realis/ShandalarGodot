extends CardScript
## Infantry Veteran — {W} — Creature — Human Soldier (common, vis).
## Oracle: {T}: Target attacking creature gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Infantry Veteran", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}: Target attacking creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
