extends CardScript
## Sanctum Guardian — {1}{W}{W} — Creature — Human Cleric (uncommon, usg).
## Oracle: Sacrifice this creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sanctum Guardian", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 4)
	c.with_subtypes(["human","cleric"])
	c.oracle("Sacrifice this creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
