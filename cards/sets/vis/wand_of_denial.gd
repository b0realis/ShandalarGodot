extends CardScript
## Wand of Denial — {2} — Artifact (rare, vis).
## Oracle: {T}: Look at the top card of target player's library. If it's a nonland card, you may pay 2 life. If you do, put it into that player's graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wand of Denial", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}: Look at the top card of target player's library. If it's a nonland card, you may pay 2 life. If you do, put it into that player's graveyard.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
