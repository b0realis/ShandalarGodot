extends CardScript
## Two-Headed Giant of Foriys — {4}{R} — Creature — Giant — 4/4 — (2ed, rare)
## Oracle: Trample
##         This creature can block an additional creature each combat.
##
## Implementation: both halves are real. The second line is
## CardData.extra_blocks (CR 509.1b), the printed permission to block more
## than one attacker — MtgGame.declare_blockers reads the live value and
## CombatState.extra_blocks records the second block, so the Giant really
## does eat two attackers and take damage from both. The engine grew
## one-to-many blocks on 2026-09-02 for this line and Blaze of Glory's.
##
## Trample and the second block interact exactly as printed: the Giant
## deals its 4 power divided among the attackers it blocks (it is the
## BLOCKER, so nothing tramples over anything), and each attacker it
## blocks assigns its damage to the Giant.


func build() -> CardData:
	return CardData.new("Two-Headed Giant of Foriys", "{4}{R}", Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["giant"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.with_extra_blocks(1) \
		.oracle("Trample\nThis creature can block an additional creature each combat.")
