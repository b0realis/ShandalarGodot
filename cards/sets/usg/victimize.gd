extends CardScript
## Victimize — {2}{B} — Sorcery (uncommon, usg).
## Oracle: Choose two target creature cards in your graveyard. Sacrifice a creature. If you do, return the chosen cards to the battlefield tapped.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.
## The returned cards enter together (MtgGame.put_onto_battlefield_together). See cards/sets/usg/_choices.gd.

func build() -> CardData:
	var c := CardData.new("Victimize", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Choose two target creature cards in your graveyard. Sacrifice a creature. If you do, return the chosen cards to the battlefield tapped.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
