extends CardScript
## Entropic Specter — {3}{B}{B} — Creature — Specter Spirit (rare, exo).
## Oracle: Flying
##         As this creature enters, choose an opponent.
##         Entropic Specter's power and toughness are each equal to the number of cards in the chosen player's hand.
##         Whenever this creature deals damage to a player, that player discards a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Entropic Specter", "{3}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["specter","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAs this creature enters, choose an opponent.\nEntropic Specter's power and toughness are each equal to the number of cards in the chosen player's hand.\nWhenever this creature deals damage to a player, that player discards a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
