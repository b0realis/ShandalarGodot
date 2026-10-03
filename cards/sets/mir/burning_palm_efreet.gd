extends CardScript
## Burning Palm Efreet — {2}{R}{R} — Creature — Efreet (uncommon, mir).
## Oracle: {1}{R}{R}: This creature deals 2 damage to target creature with flying and that creature loses flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Burning Palm Efreet", "{2}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["efreet"])
	c.oracle("{1}{R}{R}: This creature deals 2 damage to target creature with flying and that creature loses flying until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
