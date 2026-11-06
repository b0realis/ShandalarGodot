extends CardScript
## Wirecat — {4} — Artifact Creature — Cat (uncommon, usg).
## Oracle: This creature can't attack or block if an enchantment is on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wirecat", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 3)
	c.with_subtypes(["cat"])
	c.oracle("This creature can't attack or block if an enchantment is on the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
