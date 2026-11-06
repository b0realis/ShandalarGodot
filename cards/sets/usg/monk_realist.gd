extends CardScript
## Monk Realist — {1}{W} — Creature — Human Monk Cleric (common, usg).
## Oracle: When this creature enters, destroy target enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Monk Realist", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","monk","cleric"])
	c.oracle("When this creature enters, destroy target enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
