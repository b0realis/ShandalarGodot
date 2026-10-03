extends CardScript
## Tropical Storm — {X}{G} — Sorcery (uncommon, mir).
## Oracle: Tropical Storm deals X damage to each creature with flying and 1 additional damage to each blue creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tropical Storm", "{X}{G}", Mtg.CardType.SORCERY)
	c.oracle("Tropical Storm deals X damage to each creature with flying and 1 additional damage to each blue creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
