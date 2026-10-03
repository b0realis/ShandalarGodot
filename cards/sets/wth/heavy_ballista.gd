extends CardScript
## Heavy Ballista — {3}{W} — Creature — Human Soldier (common, wth).
## Oracle: {T}: This creature deals 2 damage to target attacking or blocking creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heavy Ballista", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}: This creature deals 2 damage to target attacking or blocking creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
