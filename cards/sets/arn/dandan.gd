extends CardScript
## Dandân — {U}{U} — Creature — Fish — 4/1 — (arn, common)
## Oracle: This creature can't attack unless defending player controls an
##         Island.
##         When you control no Islands, sacrifice this creature.
##
## Implementation: both clauses are engine features now —
## with_attack_needs_defender_land("island") for the attack restriction
## and with_sacrifice_if_no_land("island") for the drowning clause, which
## MtgGame checks as a state-based action. A 4/1 for two, playable only in
## a mirror-ish Island world; the same clause pair lifted the Sea Serpent
## and Pirate Ship ledger rows.


func build() -> CardData:
	return CardData.new("Dandân", "{U}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 1) \
		.with_subtypes(["fish"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.oracle("This creature can't attack unless defending player controls an Island.\n"
			+ "When you control no Islands, sacrifice this creature.")
