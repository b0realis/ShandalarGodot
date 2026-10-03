extends CardScript
## Forbidden Ritual — {2}{B}{B} — Sorcery (rare, vis).
## Oracle: Sacrifice a nontoken permanent. If you do, target opponent loses 2 life unless that player sacrifices a permanent of their choice or discards a card. You may repeat this process any number of times.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Forbidden Ritual", "{2}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Sacrifice a nontoken permanent. If you do, target opponent loses 2 life unless that player sacrifices a permanent of their choice or discards a card. You may repeat this process any number of times.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
