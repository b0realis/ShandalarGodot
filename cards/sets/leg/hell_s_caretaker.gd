extends CardScript
## Hell's Caretaker — {3}{B} — Creature — Horror — 1/1 — (leg, rare)
## Oracle: {T}, Sacrifice a creature: Return target creature card from
##         your graveyard to the battlefield. Activate only during your
##         upkeep.
##
## Implementation: tap + "sacrifice a creature" as the cost, a
## ReturnFromGraveyardEffect.to_battlefield() as the payload, and both
## upkeep riders (during_step + your_turn_only). One trade up a turn — a
## 1/1 body that turns Mons's Goblin Raiders into Serra Angel.
##
## "A creature" includes the Caretaker itself — `may_sacrifice_itself()`,
## as Fallen Angel's; the engine's sacrifice-a-<filter> cost otherwise
## offers only OTHER permanents (until 2026-10-03 a lone Caretaker could not
## pay). Tapping and sacrificing it are both costs of one activation, paid
## together, in any order (CR 601.2h via 602.2b).


func build() -> CardData:
	return CardData.new("Hell's Caretaker", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["horror"]) \
		.activated(ActivatedAbility.new(
			"", true, [ReturnFromGraveyardEffect.new().to_battlefield()],
			"{T}, Sacrifice a creature: Return target creature card from your "
			+ "graveyard to the battlefield. Activate only during your upkeep.") \
			.with_sacrifice_of("creature", _is_creature) \
			.may_sacrifice_itself() \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("{T}, Sacrifice a creature: Return target creature card from your "
			+ "graveyard to the battlefield. Activate only during your upkeep.")


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()
