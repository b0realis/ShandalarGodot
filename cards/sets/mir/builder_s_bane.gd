extends CardScript
## Builder's Bane — {X}{X}{R} — Sorcery (common, mir).
## Oracle: Destroy X target artifacts. Builder's Bane deals damage to each player equal to the number of artifacts they controlled that were put into a graveyard this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Builder's Bane", "{X}{X}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy X target artifacts. Builder's Bane deals damage to each player equal to the number of artifacts they controlled that were put into a graveyard this way.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
