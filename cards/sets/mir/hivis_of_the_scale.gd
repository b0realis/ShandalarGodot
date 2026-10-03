extends CardScript
## Hivis of the Scale — {3}{R}{R} — Legendary Creature — Lizard Shaman (rare, mir).
## Oracle: You may choose not to untap Hivis during your untap step.
##         {T}: Gain control of target Dragon for as long as you control Hivis and Hivis remains tapped.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hivis of the Scale", "{3}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["lizard","shaman"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("You may choose not to untap Hivis during your untap step.\n{T}: Gain control of target Dragon for as long as you control Hivis and Hivis remains tapped.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
