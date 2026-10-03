extends CardScript
## Reign of Chaos — {2}{R}{R} — Sorcery (uncommon, mir).
## Oracle: Choose one —
##         • Destroy target Plains and target white creature.
##         • Destroy target Island and target blue creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reign of Chaos", "{2}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Choose one —\n• Destroy target Plains and target white creature.\n• Destroy target Island and target blue creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
