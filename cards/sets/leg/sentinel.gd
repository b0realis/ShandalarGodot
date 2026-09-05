extends CardScript
## Sentinel — {4} — Artifact Creature — Shapeshifter — 1/1 — (leg, rare)
## Oracle: {0}: Change this creature's base toughness to 1 plus the power of
##         target creature blocking or blocked by this creature. (This
##         effect lasts indefinitely.)
##
## Implementation: the new base toughness is written into the Sentinel's own
## card memory and applied by a static marked
## StaticAbility.setting_base_pt(), which is CR 613 layer 7b — so counters
## and pumps still layer on top of it, and the number itself lasts
## INDEFINITELY rather than expiring at cleanup, which is what the printed
## parenthetical asks for and what a floating until-end-of-turn set could
## not give.
##
## The power is read once, when the ability resolves (CR 608.2h): the
## Sentinel keeps the number, not a link to the creature, so killing the
## attacker afterwards does not shrink it back.
##
## Free to activate and usable at instant speed, so the real line is to
## activate it AFTER blockers are declared, against the biggest thing facing
## it — a 1/1 that is suddenly a 1/8 wall.


func build() -> CardData:
	return CardData.new("Sentinel", "{4}", Mtg.CardType.ARTIFACT
			| Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["shapeshifter"]) \
		.activated(ActivatedAbility.new("", false, [MeasureEffect.new()],
			"{0}: Change this creature's base toughness to 1 plus the power of target creature blocking or blocked by this creature.")) \
		.static_ability(StaticAbility.new(
			_apply, "This creature's base toughness is what it last measured.") \
			.setting_base_pt()) \
		.oracle("{0}: Change this creature's base toughness to 1 plus the power of "
			+ "target creature blocking or blocked by this creature. (This effect "
			+ "lasts indefinitely.)")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	if source.memory.has("base_toughness"):
		source.cur_toughness = int(source.memory["base_toughness"])


class MeasureEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature(
			"target creature blocking or blocked by this creature") \
			.with_source_filter(MeasureEffect._in_combat_with_me)

	## "Blocking or blocked by this creature" — either side of the same
	## block, read off the live combat declarations.
	static func _in_combat_with_me(game: MtgGame, source: CardInstance,
			inst: CardInstance) -> bool:
		if source == null:
			return false
		if game.combat.is_blocking(inst.id, source.id):
			return true
		return game.combat.is_blocking(source.id, inst.id)

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var other := game.find_instance(target.instance_id)
		if other == null:
			return
		# LAST KNOWN INFORMATION (CR 608.2h): the number, not the link.
		source.memory["base_toughness"] = other.cur_power + 1
		game.recalculate()
		game.check_state_based_actions()

	func describe() -> String:
		return "sets this creature's base toughness from the creature it faces"
