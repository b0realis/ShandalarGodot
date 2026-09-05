extends CardScript
## Goblin Balloon Brigade — {R} — Creature — Goblin Warrior — 1/1 — (2ed, uncommon)
## Oracle: {R}: This creature gains flying until end of turn.
##
## Implementation: a keyword-granting self PumpEffect (+0/+0 with FLYING),
## no tap in the cost — so it can take off after blockers are declared, or
## come down to block a flier. Alpha's original evasive goblin.


func build() -> CardData:
	return CardData.new("Goblin Balloon Brigade", "{R}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["goblin", "warrior"]) \
		.activated(ActivatedAbility.new(
			"{R}", false,
			[PumpEffect.new(0, 0, [Mtg.Keyword.FLYING]).self_buff()],
			"{R}: Goblin Balloon Brigade gains flying until end of turn.")) \
		.oracle("{R}: This creature gains flying until end of turn.")
