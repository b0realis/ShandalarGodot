extends CardScript
## Sea Serpent — {5}{U} — Creature — Serpent — 5/5 (2ed, common)
## Oracle: Sea Serpent can't attack unless defending player controls an
##         Island.
##         When you control no Islands, sacrifice Sea Serpent.
##
## Implementation: the attack-restriction clause via
## with_attack_needs_defender_land("island") — CombatState.attack_illegality
## checks the DEFENDER's lands by subtype (their Tropical Island counts) —
## plus with_sacrifice_if_no_land("island") for the printed second line,
## which MtgGame enforces as a state-based action (wave 27 lifted the old
## ledger row).


func build() -> CardData:
	return CardData.new("Sea Serpent", "{5}{U}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_subtypes(["serpent"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.oracle("Sea Serpent can't attack unless defending player controls an Island.\n"
			+ "When you control no Islands, sacrifice Sea Serpent.")
