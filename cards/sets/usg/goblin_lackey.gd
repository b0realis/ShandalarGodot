extends CardScript
## Goblin Lackey — {R} — Creature — Goblin (uncommon, usg).
## Oracle: Whenever this creature deals damage to a player, you may put a Goblin permanent card from your hand onto the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Lackey", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin"])
	c.oracle("Whenever this creature deals damage to a player, you may put a Goblin permanent card from your hand onto the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
