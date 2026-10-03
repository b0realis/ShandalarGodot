extends CardScript
## Suq'Ata Firewalker — {1}{U}{U} — Creature — Human Wizard (uncommon, mir).
## Oracle: This creature can't be the target of red spells or abilities from red sources.
##         {T}: This creature deals 1 damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Suq'Ata Firewalker", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("This creature can't be the target of red spells or abilities from red sources.\n{T}: This creature deals 1 damage to any target.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
