extends CardScript
## Mana Leech — {2}{B} — Creature — Leech (uncommon, usg).
## Oracle: You may choose not to untap this creature during your untap step.
##         {T}: Tap target land. It doesn't untap during its controller's untap step for as long as this creature remains tapped.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Leech", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["leech"])
	c.oracle("You may choose not to untap this creature during your untap step.\n{T}: Tap target land. It doesn't untap during its controller's untap step for as long as this creature remains tapped.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
