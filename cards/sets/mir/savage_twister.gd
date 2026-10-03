extends CardScript
## Savage Twister — {X}{R}{G} — Sorcery (uncommon, mir).
## Oracle: Savage Twister deals X damage to each creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Savage Twister", "{X}{R}{G}", Mtg.CardType.SORCERY)
	c.oracle("Savage Twister deals X damage to each creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
