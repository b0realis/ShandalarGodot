extends CardScript
## Expendable Troops — {1}{W} — Creature — Human Soldier (common, ulg).
## Oracle: {T}, Sacrifice this creature: It deals 2 damage to target attacking or blocking creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Expendable Troops", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","soldier"])
	c.oracle("{T}, Sacrifice this creature: It deals 2 damage to target attacking or blocking creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
