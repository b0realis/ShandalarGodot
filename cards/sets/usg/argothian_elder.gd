extends CardScript
## Argothian Elder — {3}{G} — Creature — Elf Druid (uncommon, usg).
## Oracle: {T}: Untap two target lands.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argothian Elder", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["elf","druid"])
	c.oracle("{T}: Untap two target lands.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
