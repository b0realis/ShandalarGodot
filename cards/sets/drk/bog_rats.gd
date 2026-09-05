extends CardScript
## Bog Rats — {B} — Creature — Rat — 1/1 — (drk, common)
## Oracle: This creature can't be blocked by Walls.
##
## Implementation: the Juggernaut clause on a one-drop — Walls simply
## can't block it (cant_be_blocked_by).


func build() -> CardData:
	return CardData.new("Bog Rats", "{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["rat"]) \
		.with_cant_be_blocked_by(["wall"]) \
		.oracle("This creature can't be blocked by Walls.")
