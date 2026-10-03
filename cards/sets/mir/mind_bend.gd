extends CardScript
## Mind Bend — {U} — Instant (uncommon, mir).
## Oracle: Change the text of target permanent by replacing all instances of one color word with another or one basic land type with another. (For example, you may change "nonblack creature" to "nongreen creature" or "forestwalk" to "islandwalk." This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## SIMPLIFIED (docs/simplified-cards.md, "Text changes"): like Sleight of
## Mind and Magical Hack, the rewrite reaches only the words this engine
## stores (protection colours, land subtypes, landwalk), so only permanents
## carrying one are offered as targets (cards/sets/mir/_spells.gd MindBend).

func build() -> CardData:
	var c := CardData.new("Mind Bend", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Change the text of target permanent by replacing all instances of one color word with another or one basic land type with another. (For example, you may change \"nonblack creature\" to \"nongreen creature\" or \"forestwalk\" to \"islandwalk.\" This effect lasts indefinitely.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
