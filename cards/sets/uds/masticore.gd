extends CardScript
## Masticore — {4} — Artifact Creature — Masticore (rare, uds).
## Oracle: At the beginning of your upkeep, sacrifice this creature unless you discard a card.
##         {2}: This creature deals 1 damage to target creature.
##         {2}: Regenerate this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Masticore", "{4}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(4, 4)
	c.with_subtypes(["masticore"])
	c.oracle("At the beginning of your upkeep, sacrifice this creature unless you discard a card.\n{2}: This creature deals 1 damage to target creature.\n{2}: Regenerate this creature.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
