extends CardScript
## Reflecting Mirror — {4} — Artifact — (drk, uncommon)
## Oracle: {X}, {T}: Change the target of target spell with a single target
##         if that target is you. The new target must be a player. X is
##         twice the mana value of that spell.
##
## Implementation: two engine pieces, both new and both small.
## - MtgGame.retarget_spell rewrites one slot of a spell already on the
##   stack, in both the flat list and the per-effect group, so resolution
##   and the fizzle check cannot disagree.
## - ActivatedAbility.with_x_condition is how "X is twice the mana value of
##   that spell" becomes a REFUSAL rather than a wasted activation: the
##   condition sees the chosen targets as well as X, which is the only way
##   to know what X has to be.
##
## The targeting requirement — "a spell with a SINGLE target, and that
## target is you" — lives in the TargetSpec, where a targeting restriction
## belongs, and reads the spell's own StackItem.
##
## The new target is the opponent: a duel has one other player, and the
## printed line only demands that it be a player. Four mana plus twice the
## spell's cost is a steep price, and paying it turns their Fireball around.


func build() -> CardData:
	return CardData.new("Reflecting Mirror", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{X}", true, [MirrorEffect.new()],
			"{X}, {T}: Change the target of target spell with a single target if that target is you. X is twice the mana value of that spell.") \
			.with_x_condition(_twice_its_mana_value)) \
		.oracle("{X}, {T}: Change the target of target spell with a single target "
			+ "if that target is you. The new target must be a player. X is twice "
			+ "the mana value of that spell.")


## "X is twice the mana value of that spell" — checked before any cost is
## paid, so naming the wrong X is refused rather than wasted.
static func _twice_its_mana_value(game: MtgGame, _source: CardInstance,
		x_value: int, targets: Array) -> String:
	if targets.is_empty():
		return ""
	var spell := game.find_instance(targets[0].instance_id)
	if spell == null:
		return ""
	var due := MirrorEffect.price_of(game, spell)
	if x_value != due:
		return "X must be %d (twice %s's mana value)" % [due, spell.data.card_name]
	return ""


class MirrorEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell(
			"target spell with a single target, if that target is you") \
			.with_source_filter(MirrorEffect._aimed_at_my_controller)

	## The spell's mana value, doubled — with the chosen X folded in, since
	## a spell on the stack has its X (CR 202.3b).
	static func price_of(game: MtgGame, spell: CardInstance) -> int:
		var value := spell.data.cost.mana_value()
		var item := game.find_stack_item(spell)
		if item != null and spell.data.cost.has_x:
			value += item.x_value * spell.data.cost.x_count
		return value * 2

	## "A spell with a SINGLE target, if that target is you."
	static func _aimed_at_my_controller(game: MtgGame, source: CardInstance,
			spell: CardInstance) -> bool:
		if source == null or spell.zone != Mtg.Zone.STACK:
			return false
		var item := game.find_stack_item(spell)
		if item == null or item.targets.size() != 1:
			return false
		var ref: TargetRef = item.targets[0]
		return ref.is_player and ref.player_id == source.controller_id

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var spell := game.find_instance(target.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK or source == null:
			return
		# "The new target must be a player" — in a duel, the other one.
		game.retarget_spell(spell, 0,
			TargetRef.player(game.opponent_of(controller)))

	func describe() -> String:
		return "turns a spell aimed at you back on its caster"
