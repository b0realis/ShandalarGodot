extends CardScript
## Titania's Chosen — {2}{G} — Creature — Elf Archer (uncommon, usg).
## Oracle: Whenever a player casts a green spell, put a +1/+1 counter on this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Titania's Chosen", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf","archer"])
	c.oracle("Whenever a player casts a green spell, put a +1/+1 counter on this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
