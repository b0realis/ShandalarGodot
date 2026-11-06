extends CardScript
## Pygmy Pyrosaur — {1}{R} — Creature — Lizard (common, ulg).
## Oracle: This creature can't block.
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pygmy Pyrosaur", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["lizard"])
	c.oracle("This creature can't block.\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
