extends CardScript
## Rock Hydra — {X}{R}{R} — Creature — Hydra — 0/0 — (2ed, rare)
## Oracle: This creature enters with X +1/+1 counters on it.
##         For each 1 damage that would be dealt to this creature, if it has
##         a +1/+1 counter on it, remove a +1/+1 counter from it and prevent
##         that 1 damage.
##         {R}: Prevent the next 1 damage that would be dealt to this
##         creature this turn.
##         {R}{R}{R}: Put a +1/+1 counter on this creature. Activate only
##         during your upkeep.
##
## Implementation: four clauses, and only the second needed anything new.
## - X counters arrive through CardData.as_it_enters, a real replacement
##   (CR 614.1c), reading the X the cast recorded on the instance's own
##   memory — so a 0/0 Hydra is never on the battlefield for state-based
##   actions to bury.
## - "For each 1 damage ... remove a +1/+1 counter and prevent that 1
##   damage" is CardInstance.damage_eats_counters (new), a replacement and
##   one of the engine's three METERED damage gates. Counter for point:
##   3 damage to a Hydra with 2 counters eats both and 1 gets through,
##   which is what kills it.
## - The {R} shield is the engine's ordinary prevention pool, and the two
##   meet on the same body. CORRECTED 2026-09-11: this note used to say the
##   pool was spent before the counters were, and the engine had always
##   done the opposite. Neither is the engine's to decide — CR 616.1 gives
##   the ordering to the creature's controller, and it matters here as much
##   as anywhere in the pool: 2 damage into a Hydra with three counters and
##   two {R} shields leaves either a 1/1 with its shields or a 3/3 without
##   them. Counters first is the default answer, which is what this card
##   always did (tests/unit/test_creature_damage_gate_order_2026_09_11.gd).
## - The {R}{R}{R} regrowth is an ordinary counter ability restricted to
##   your upkeep step.
##
## `@ROCK_HYDRA`, `Program/promptsX1.txt:355`, is the 1997 game asking which
## damage the {R} shield should eat: `Select a damage card on Rock Hydra.`


func build() -> CardData:
	return CardData.new("Rock Hydra", "{X}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["hydra"]) \
		.as_it_enters(_grow_heads) \
		.static_ability(StaticAbility.new(
			_heads_soak_damage, "For each 1 damage that would be dealt to this creature, if it has a +1/+1 counter on it, remove a +1/+1 counter from it and prevent that 1 damage.")) \
		.activated(ActivatedAbility.new("{R}", false, [
				PreventDamageEffect.new(1).to_source()],
			"{R}: Prevent the next 1 damage that would be dealt to this creature this turn.")) \
		.activated(ActivatedAbility.new("{R}{R}{R}", false, [RegrowEffect.new()],
			"{R}{R}{R}: Put a +1/+1 counter on this creature. Activate only during your upkeep.") \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("This creature enters with X +1/+1 counters on it.\nFor each 1 "
			+ "damage that would be dealt to this creature, if it has a +1/+1 "
			+ "counter on it, remove a +1/+1 counter from it and prevent that 1 "
			+ "damage.\n{R}: Prevent the next 1 damage that would be dealt to this "
			+ "creature this turn.\n{R}{R}{R}: Put a +1/+1 counter on this creature. "
			+ "Activate only during your upkeep.")


## The X heads, as a replacement rather than a trigger — the Hydra is never
## a 0/0 on the battlefield.
static func _grow_heads(game: MtgGame, inst: CardInstance,
		_controller: int) -> void:
	var heads := int(inst.memory.get("x_value", 0))
	if heads > 0:
		game.add_counters(inst, "+1/+1", heads)


static func _heads_soak_damage(_game: MtgGame, source: CardInstance) -> void:
	source.damage_eats_counters = "+1/+1"


class RegrowEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source != null and source.zone == Mtg.Zone.BATTLEFIELD:
			game.add_counters(source, "+1/+1", 1)

	func describe() -> String:
		return "grows a new head"
