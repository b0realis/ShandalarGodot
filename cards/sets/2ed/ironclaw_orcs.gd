extends CardScript
## Ironclaw Orcs — {1}{R} — Creature — Orc — 2/2 — (2ed, common)
## Oracle: This creature can't block creatures with power 2 or greater.
##
## Implementation: the blocker-side power restriction (engine field
## cant_block_power_ge, checked against the attacker's LIVE power — a
## Giant Growth mid-combat can't retroactively illegalize a declared
## block, but at declaration the pumped power counts).


func build() -> CardData:
	return CardData.new("Ironclaw Orcs", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["orc"]) \
		.with_cant_block_power_ge(2) \
		.oracle("This creature can't block creatures with power 2 or greater.")
