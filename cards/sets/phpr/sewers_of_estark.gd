extends CardScript
## Sewers of Estark — {2}{B}{B} — Instant — (phpr, rare)
## Oracle: Choose target creature. If it's attacking, it can't be blocked
##         this turn. If it's blocking, prevent all combat damage that would
##         be dealt this combat by it and each creature it's blocking.
##
## Implementation: one target, two mutually exclusive riders decided at
## RESOLUTION (the printed "if it's attacking / if it's blocking" is not a
## targeting restriction, so the spell may be cast at anything and simply
## does nothing to a creature standing still).
##
## - Attacking: a floating UNBLOCKABLE grant (Teleport's mechanism). Cast
##   after blockers are declared it changes nothing, because a creature
##   that is already blocked stays blocked (CR 509.1h).
## - Blocking: a floating "prevent the combat damage this creature would
##   DEAL", applied to the blocker AND to every attacker it is blocking —
##   both halves of that fight go quiet, which is what makes this a
##   two-sided Fog rather than a removal spell.


func build() -> CardData:
	return CardData.new("Sewers of Estark", "{2}{B}{B}", Mtg.CardType.INSTANT) \
		.spell(SewersEffect.new()) \
		.oracle("Choose target creature. If it's attacking, it can't be blocked this turn. "
			+ "If it's blocking, prevent all combat damage that would be dealt this combat "
			+ "by it and each creature it's blocking.")


class SewersEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		if game.combat.attackers.has(inst.id):
			game.continuous.add_until_eot_pump(inst.id, 0, 0, [Mtg.Keyword.UNBLOCKABLE])
			game.recalculate()
			return
		if not game.combat.blocks.has(inst.id):
			return
		game.continuous.add_until_eot_combat_prevention(inst.id, true, false, true)
		for id in game.combat.opposing_attackers(inst.id):
			game.continuous.add_until_eot_combat_prevention(int(id), true, false, true)
		game.recalculate()

	func describe() -> String:
		return "target attacker becomes unblockable, or target blocker's fight goes quiet"
