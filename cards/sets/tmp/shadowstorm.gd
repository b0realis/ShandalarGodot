extends CardScript
## Shadowstorm — {R} — Sorcery (uncommon, tmp).
## Oracle: Shadowstorm deals 2 damage to each creature with shadow.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shadowstorm", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Shadowstorm deals 2 damage to each creature with shadow.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
