extends CardScript
## Return of the Nightstalkers — {5}{B}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Return all Nightstalker permanent cards from your graveyard to the battlefield. Then destroy all Swamps you control.

func build() -> CardData:
	var c := CardData.new("Return of the Nightstalkers", "{5}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Return all Nightstalker permanent cards from your graveyard to the battlefield. Then destroy all Swamps you control.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
