extends CardScript
## Bubbling Muck — {B} — Sorcery (common, uds).
## Oracle: Until end of turn, whenever a player taps a Swamp for mana, that player adds an additional {B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bubbling Muck", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Until end of turn, whenever a player taps a Swamp for mana, that player adds an additional {B}.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
