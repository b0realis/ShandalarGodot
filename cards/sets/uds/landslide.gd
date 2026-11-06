extends CardScript
## Landslide — {R} — Sorcery (uncommon, uds).
## Oracle: Sacrifice any number of Mountains. Landslide deals that much damage to target player or planeswalker.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Landslide", "{R}", Mtg.CardType.SORCERY)
	c.oracle("Sacrifice any number of Mountains. Landslide deals that much damage to target player or planeswalker.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
