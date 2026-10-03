extends CardScript
## Grinning Totem — {4} — Artifact (rare, mir).
## Oracle: {2}, {T}, Sacrifice this artifact: Search target opponent's library for a card and exile it. Then that player shuffles. Until the beginning of your next upkeep, you may play that card. At the beginning of your next upkeep, if you haven't played it, put it into its owner's graveyard.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grinning Totem", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{2}, {T}, Sacrifice this artifact: Search target opponent's library for a card and exile it. Then that player shuffles. Until the beginning of your next upkeep, you may play that card. At the beginning of your next upkeep, if you haven't played it, put it into its owner's graveyard.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
