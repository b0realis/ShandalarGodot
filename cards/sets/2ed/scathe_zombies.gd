extends CardScript
## Scathe Zombies — {2}{B} — Creature — Zombie — 2/2 (Alpha, common)
## Oracle: (no rules text — vanilla creature)
##
## Implementation: pure stats. Included in the starter pool chiefly as the
## canonical BLACK creature for testing color-filtered removal (Terror
## must refuse to target it).


func build() -> CardData:
	return CardData.new("Scathe Zombies", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["zombie"]) \
		.oracle("")
