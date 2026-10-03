extends CardScript
## Tendrils of Despair — {B} — Sorcery (common, wth).
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Target opponent discards two cards.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tendrils of Despair", "{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice a creature.\nTarget opponent discards two cards.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
