extends CardScript
## Whim of Volrath — {U} — Instant (rare, tmp).
## Oracle: Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)
##         Change the text of target permanent by replacing all instances of one color word with another or one basic land type with another until end of turn. (For example, you may change "nonred creature" to "nongreen creature" or "plainswalk" to "swampwalk.")
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.
## SIMPLIFIED (docs/simplified-cards.md, "Text changes"): only the words this engine models — protection colours, land types and landwalk. See cards/sets/tmp/_buyback.gd Whim.

func build() -> CardData:
	var c := CardData.new("Whim of Volrath", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Buyback {2} (You may pay an additional {2} as you cast this spell. If you do, put this card into your hand as it resolves.)\nChange the text of target permanent by replacing all instances of one color word with another or one basic land type with another until end of turn. (For example, you may change \"nonred creature\" to \"nongreen creature\" or \"plainswalk\" to \"swampwalk.\")")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
