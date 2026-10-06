extends CardScript
## Reanimate — {B} — Sorcery (uncommon, tmp).
## Oracle: Put target creature card from a graveyard onto the battlefield under your control. You lose life equal to that card's mana value.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reanimate", "{B}", Mtg.CardType.SORCERY)
	c.oracle("Put target creature card from a graveyard onto the battlefield under your control. You lose life equal to that card's mana value.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
