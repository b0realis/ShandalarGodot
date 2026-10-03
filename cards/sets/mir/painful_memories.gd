extends CardScript
## Painful Memories — {1}{B} — Sorcery (uncommon, mir).
## Oracle: Look at target opponent's hand and choose a card from it. Put that card on top of that player's library.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Painful Memories", "{1}{B}", Mtg.CardType.SORCERY)
	c.oracle("Look at target opponent's hand and choose a card from it. Put that card on top of that player's library.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
