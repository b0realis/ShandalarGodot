extends CardScript
## Treetop Rangers — {2}{G} — Creature — Elf Ranger (common, usg).
## Oracle: This creature can't be blocked except by creatures with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treetop Rangers", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf","ranger"])
	c.oracle("This creature can't be blocked except by creatures with flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
