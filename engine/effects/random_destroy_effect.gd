class_name RandomDestroyEffect
extends EffectBase
## Destroy a uniformly random subset of permanents controlled by a target
## player. This is the digital effect vocabulary for physical-placement
## cards such as Chaos Orb; the card decides which restrictions apply.

var count: int = 1
var exclude_tokens: bool = false
var require_source_on_battlefield: bool = false
var destroy_source_after: bool = false
var requires_won_coin_flip: bool = false


func _init(p_count := 1) -> void:
	count = maxi(p_count, 0)
	target_spec = TargetSpec.opponent()


## Ignore token permanents when building the random pool.
func nontoken_only() -> RandomDestroyEffect:
	exclude_tokens = true
	return self


## Do nothing unless the resolving source is still on the battlefield.
func while_source_remains() -> RandomDestroyEffect:
	require_source_on_battlefield = true
	return self


## Destroy the source after resolving the random destruction.
func then_destroy_source() -> RandomDestroyEffect:
	destroy_source_after = true
	return self


## Gate the random destruction behind one shared, seeded coin flip. The
## source's after-resolution rider still happens on a loss.
func on_won_coin_flip() -> RandomDestroyEffect:
	requires_won_coin_flip = true
	return self


## The exact pool resolution and the AI both read. Keeping it here prevents
## the pilot from estimating a different lottery from the one the game rolls.
func candidates(game: MtgGame, target_player: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in game.players[target_player].battlefield:
		if exclude_tokens and inst.is_token:
			continue
		out.append(inst)
	return out


func resolve(game: MtgGame, source: CardInstance, _controller: int,
		target: TargetRef, _x_value: int = 0) -> void:
	if require_source_on_battlefield \
			and not game.is_present(source):   # incl. phased out (CR 702.26b)
		return
	if not requires_won_coin_flip or game.flip_coin(_controller):
		var pool := candidates(game, target.player_id)
		for picked in RandomEffects.sample(game, pool, count):
			game.destroy(picked)
	if destroy_source_after and source != null:
		game.destroy(source)


func describe() -> String:
	var amount := "a" if count == 1 else str(count)
	var kind := "nontoken permanent" if exclude_tokens else "permanent"
	var gate := "on a won coin flip, " if requires_won_coin_flip else ""
	return "%sdestroys %s random %s controlled by target opponent" % [gate, amount, kind]
