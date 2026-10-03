extends CardScript
## Mangara's Blessing — {2}{W} — Instant (uncommon, mir).
## Oracle: You gain 5 life.
##         When a spell or ability an opponent controls causes you to discard this card, you gain 2 life, and you return this card from your graveyard to your hand at the beginning of the next end step.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mangara's Blessing", "{2}{W}", Mtg.CardType.INSTANT)
	c.oracle("You gain 5 life.\nWhen a spell or ability an opponent controls causes you to discard this card, you gain 2 life, and you return this card from your graveyard to your hand at the beginning of the next end step.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
