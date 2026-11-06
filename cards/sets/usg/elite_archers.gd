extends CardScript
## Elite Archers — {5}{W} — Creature — Human Soldier Archer (rare, usg).
## Oracle: {T}: This creature deals 3 damage to target attacking or blocking creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Elite Archers", "{5}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["human","soldier","archer"])
	c.oracle("{T}: This creature deals 3 damage to target attacking or blocking creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
