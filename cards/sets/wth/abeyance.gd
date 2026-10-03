extends CardScript
## Abeyance — {1}{W} — Instant (rare, wth).
## Oracle: Until end of turn, target player can't cast instant or sorcery spells, and that player can't activate abilities that aren't mana abilities.
##         Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Abeyance", "{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Until end of turn, target player can't cast instant or sorcery spells, and that player can't activate abilities that aren't mana abilities.\nDraw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
