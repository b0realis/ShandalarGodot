extends CardScript
## Fireball — {X}{R} — Sorcery (2ed, common)
## Oracle: This spell costs {1} more to cast for each target beyond the
##         first. Fireball deals X damage divided evenly, rounded down,
##         among any number of targets.
##
## Implementation: the real card at last. "Divided EVENLY, rounded down"
## is not the player's choice — each of the N chosen targets takes
## floor(X / N) — so this is a divided effect only in the sense that it
## needs the whole target group at once; the shares are computed here.
##
## N IS THE NUMBER OF TARGETS CHOSEN, fixed as the spell is cast (CR 601.2d)
## — the owner's ruling of 2026-10-21, verbatim: *"how Fireball divides its
## damage when one of its targets is gone (it is ignored if target
## dissapears - the spell crushes empty space :))"*. A target that is gone
## or illegal on resolution loses its share (CR 608.2b) and the others
## keep theirs: X=6 at two creatures, one bounced in response, is 3 to the
## one left, not 6. Until then N was the targets still legal, so one
## dropping out doubled the damage to the other. MtgGame.chosen_target_count
## says how many were chosen; with every target gone the spell does
## nothing at all (MtgGame skips an effect with no legal target left).
##
## The "{1} more for each target beyond the first" surcharge is a cost
## modifier the card carries itself (CardData.extra_cost_per_target), read
## by MtgGame while it prices the cast.


func build() -> CardData:
	return CardData.new("Fireball", "{X}{R}", Mtg.CardType.SORCERY) \
		.with_extra_cost_per_target(1) \
		.spell(FireballEffect.new()) \
		.oracle("This spell costs {1} more to cast for each target beyond the first.\nFireball deals X damage divided evenly, rounded down, among any number of targets.")


class FireballEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()
		one_or_more()

	func resolve_multi(game: MtgGame, source: CardInstance, _controller: int,
			targets: Array, x_value: int = 0) -> void:
		if targets.is_empty():
			return
		# Divided among the targets CHOSEN, the gone ones included (the
		# owner's ruling of 2026-10-21). A direct call outside a resolution
		# has no count to read and divides among what it was handed.
		var chosen := maxi(game.chosen_target_count(), targets.size())
		var each: int = x_value / chosen   # integer division = rounded down
		if each <= 0:
			return
		for ref in targets:
			game.deal_damage(source, ref, each)

	func describe() -> String:
		return "deals X damage divided evenly, rounded down, among any number of targets"
