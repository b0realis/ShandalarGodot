extends CardScript
## Flicker — {1}{W} — Sorcery (rare, uds).
## Oracle: Exile target nontoken permanent, then return it to the battlefield under its owner's control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flicker", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("Exile target nontoken permanent, then return it to the battlefield under its owner's control.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
