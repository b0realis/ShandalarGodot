extends CardScript
## Amrou Kithkin — {W}{W} — Creature — Kithkin — 1/1 — (4ed, common)
## Oracle: This creature can't be blocked by creatures with power 3 or
##         greater.
##
## Implementation: the attacker-side power restriction (engine field
## cant_be_blocked_by_power_ge, live blocker power) — only the small may
## stand in its way.


func build() -> CardData:
	return CardData.new("Amrou Kithkin", "{W}{W}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["kithkin"]) \
		.with_cant_be_blocked_by_power_ge(3) \
		.oracle("This creature can't be blocked by creatures with power 3 or greater.")
