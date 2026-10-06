extends CardScript
## Master Decoy — {1}{W} — Creature — Human Soldier (common, tmp).
## Oracle: {W}, {T}: Tap target creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Master Decoy", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["human","soldier"])
	c.oracle("{W}, {T}: Tap target creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
