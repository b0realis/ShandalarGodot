extends CardScript
## Avenging Druid — {2}{G} — Creature — Human Druid (common, exo).
## Oracle: Whenever this creature deals damage to an opponent, you may reveal cards from the top of your library until you reveal a land card. If you do, put that card onto the battlefield and put all other cards revealed this way into your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Avenging Druid", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 3)
	c.with_subtypes(["human","druid"])
	c.oracle("Whenever this creature deals damage to an opponent, you may reveal cards from the top of your library until you reveal a land card. If you do, put that card onto the battlefield and put all other cards revealed this way into your graveyard.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
