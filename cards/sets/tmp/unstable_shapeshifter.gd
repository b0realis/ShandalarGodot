extends CardScript
## Unstable Shapeshifter — {3}{U} — Creature — Shapeshifter (rare, tmp).
## Oracle: Whenever another creature enters, this creature becomes a copy of that creature, except it has this ability.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unstable Shapeshifter", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["shapeshifter"])
	c.oracle("Whenever another creature enters, this creature becomes a copy of that creature, except it has this ability.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
