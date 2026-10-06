extends CardScript
## Apes of Rath — {2}{G}{G} — Creature — Ape (uncommon, tmp).
## Oracle: Whenever this creature attacks, it doesn't untap during its controller's next untap step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Apes of Rath", "{2}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["ape"])
	c.oracle("Whenever this creature attacks, it doesn't untap during its controller's next untap step.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
