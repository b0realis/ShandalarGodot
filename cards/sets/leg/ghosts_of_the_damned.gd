extends CardScript
## Ghosts of the Damned — {1}{B}{B} — Creature — Spirit — 0/2 — (leg, common)
## Oracle: {T}: Target creature gets -1/-0 until end of turn.
##
## Implementation: a free (tap-only) negative PumpEffect. -1/-0 never
## kills on its own but blanks an attacker's damage; stacking several
## Ghosts turns off a fatty for a turn.


func build() -> CardData:
	return CardData.new("Ghosts of the Damned", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 2) \
		.with_subtypes(["spirit"]) \
		.activated(ActivatedAbility.new(
			"", true,
			[PumpEffect.new(-1, 0)],
			"{T}: Target creature gets -1/-0 until end of turn.")) \
		.oracle("{T}: Target creature gets -1/-0 until end of turn.")
