extends CardScript
## Fallen Angel — {3}{B}{B} — Creature — Angel — 3/3 — (leg, uncommon)
## Oracle: Flying
##         Sacrifice a creature: This creature gets +2/+1 until end of turn.
##
## Implementation: a free activated ability whose whole cost is
## "Sacrifice a creature" (ActivatedAbility.with_sacrifice_of) — no mana,
## no tap, so the Angel can eat the whole team after blockers are
## declared. The chosen body comes from the controller's decision agent.
##
## "A creature" includes the Angel — `may_sacrifice_itself()`, because the
## engine's sacrifice-a-<filter> cost otherwise offers only OTHER
## permanents. Eating itself achieves nothing on its own (the pump has no
## Angel left to land on), but it is a legal line the moment anything on
## the board cares that a creature died — Khabál Ghoul, Osai Vultures,
## Scavenging Ghoul all do — and a cost the printed card allows must be
## payable (CONTRIBUTING.md rule 3).


func build() -> CardData:
	return CardData.new("Fallen Angel", "{3}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["angel"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"", false,
			[PumpEffect.new(2, 1).self_buff()],
			"Sacrifice a creature: Fallen Angel gets +2/+1 until end of turn.") \
			.with_sacrifice_of("creature", _is_creature) \
			.may_sacrifice_itself()) \
		.oracle("Flying\nSacrifice a creature: This creature gets +2/+1 until end of turn.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()
