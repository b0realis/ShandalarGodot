extends CardScript
## Windreaper Falcon — {1}{R}{G} — Creature — Bird (uncommon, mir).
## Oracle: Flying, protection from blue
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Windreaper Falcon", "{1}{R}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("Flying, protection from blue")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
