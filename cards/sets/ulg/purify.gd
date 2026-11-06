extends CardScript
## Purify — {3}{W}{W} — Sorcery (rare, ulg).
## Oracle: Destroy all artifacts and enchantments.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Purify", "{3}{W}{W}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all artifacts and enchantments.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
