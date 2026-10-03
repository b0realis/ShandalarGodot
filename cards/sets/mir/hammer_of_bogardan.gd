extends CardScript
## Hammer of Bogardan — {1}{R}{R} — Sorcery (rare, mir).
## Oracle: Hammer of Bogardan deals 3 damage to any target.
##         {2}{R}{R}{R}: Return this card from your graveyard to your hand. Activate only during your upkeep.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hammer of Bogardan", "{1}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Hammer of Bogardan deals 3 damage to any target.\n{2}{R}{R}{R}: Return this card from your graveyard to your hand. Activate only during your upkeep.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
