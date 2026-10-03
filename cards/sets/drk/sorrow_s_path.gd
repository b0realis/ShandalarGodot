extends CardScript
## Sorrow's Path — Land — (drk, rare)
## Oracle: {T}: Choose two target blocking creatures controlled by the same
##         opponent. If each of those creatures could block all creatures
##         that the other is blocking, remove both of them from combat.
##         Each one then blocks all creatures the other was blocking.
##         Whenever this land becomes tapped, it deals 2 damage to you and
##         each creature you control.
##
## Implementation: two targets, both blockers your opponent controls; the
## legality clause is checked at resolution (each must be able to block the
## other's attacker), and then their assignments are swapped. The famous
## drawback is a became-tapped trigger, so ANY tap — for the ability, by
## an Icy Manipulator, by anything — hurts.


static func _blocking_opponent_creature(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.controller_id != source.controller_id \
		and game.combat.blocks.has(inst.id)


## The second slot is the same target word as the first ("choose two
## target blocking creatures"), so it may not name the first one again
## (CR 601.2c). The engine judges duplicates per word, and the Path's two
## words are two effects, so the distinctness is said here (2026-10-03).
static func _not_the_first(_game: MtgGame, _source: CardInstance,
		ref: TargetRef, earlier: Array) -> bool:
	for other in earlier:
		if other is TargetRef and other.same_object(ref):
			return false
	return true


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _hurt(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pid := source.controller_id
	game.deal_damage(source, TargetRef.player(pid), 2)
	for inst in game.players[pid].battlefield.duplicate():
		if inst.is_creature():
			game.deal_damage(source, TargetRef.card(inst), 2)


func build() -> CardData:
	var first := TargetSpec.creature("target blocking creature an opponent controls")
	first.with_source_filter(_blocking_opponent_creature)
	var second := TargetSpec.creature("a second blocking creature the same opponent controls")
	second.with_source_filter(_blocking_opponent_creature)
	second.with_sibling_filter(_not_the_first, TargetSpec.WHY["blocking"])
	return CardData.new("Sorrow's Path", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("", true,
			[SwapBlocksEffect.new(first), NoopSecondTargetEffect.new(second)],
			"{T}: Choose two target blocking creatures controlled by the same opponent; they swap what they are blocking.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _hurt,
			"Whenever this land becomes tapped, it deals 2 damage to you and each creature you control.",
			_is_self)) \
		.oracle("{T}: Choose two target blocking creatures controlled by the same opponent. If each of those creatures could block all creatures that the other is blocking, remove both of them from combat. Each one then blocks all creatures the other was blocking.\nWhenever this land becomes tapped, it deals 2 damage to you and each creature you control.")


## The FIRST target's effect does the swap; it needs both refs, so it reads
## the stack item's second target through the source's memory — which the
## second effect fills in. Ordering: the engine runs effects in order, so
## the second effect stores its ref first only if it comes first. Instead
## the swap is done by the SECOND effect, and this one just records target one.
class SwapBlocksEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(_game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		source.memory["swap_first"] = target.instance_id

	func describe() -> String:
		return "chooses the first blocking creature"


class NoopSecondTargetEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var one := game.find_instance(int(source.memory.get("swap_first", -1)))
		var two := game.find_instance(target.instance_id)
		source.memory.erase("swap_first")
		if one == null or two == null or one == two:
			return
		if one.controller_id != two.controller_id:
			return
		if not game.combat.blocks.has(one.id) or not game.combat.blocks.has(two.id):
			return
		var one_target := game.find_instance(game.combat.blocks[one.id])
		var two_target := game.find_instance(game.combat.blocks[two.id])
		if one_target == null or two_target == null:
			return
		var defender := one.controller_id
		# "If each of those creatures could block all creatures that the
		# other is blocking" — the whole ability does nothing otherwise.
		if CombatState.block_illegality(game, one, two_target, defender) != "":
			return
		if CombatState.block_illegality(game, two, one_target, defender) != "":
			return
		game.remove_from_combat(one)
		game.remove_from_combat(two)
		game.set_block(one, two_target)
		game.set_block(two, one_target)

	func describe() -> String:
		return "the two blockers swap what they are blocking"
