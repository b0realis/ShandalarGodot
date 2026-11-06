extends CardScript
## Faith Healer — {1}{W} — Creature — Human Cleric (rare, usg).
## Oracle: Sacrifice an enchantment: You gain life equal to the sacrificed enchantment's mana value.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Faith Healer", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("Sacrifice an enchantment: You gain life equal to the sacrificed enchantment's mana value.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
