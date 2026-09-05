extends CardScript
## Drain Power — {U}{U} — Sorcery — (2ed, rare)
## Oracle: Target player activates a mana ability of each land they control.
##         Then that player loses all unspent mana and you add the mana lost
##         this way.
##
## Implementation: literally what it says — each of the target's lands is
## tapped for mana through MtgGame.tap_for_mana, so a land with a choice of
## abilities uses its first, a land that is already tapped simply refuses
## and is skipped, and every mana trigger (Mana Flare) fires as it would.
## The victim's whole pool — including mana they were holding before Drain
## Power resolved — then moves across, which is the printed "all unspent
## mana".
##
## RESTRICTED mana (CR 106.6, a Mishra's Workshop's "spend only on
## artifacts") is drained as PLAIN mana: the restriction belonged to the
## ability that made it, and what arrives in your pool is mana you were
## given, not mana you produced.
##
## The victim's lands stay tapped, which is half the point: Drain Power is a
## Time Walk against a mana-heavy board as much as it is a ritual.


func build() -> CardData:
	return CardData.new("Drain Power", "{U}{U}", Mtg.CardType.SORCERY) \
		.spell(DrainEffect.new()) \
		.oracle("Target player activates a mana ability of each land they control. "
			+ "Then that player loses all unspent mana and you add the mana lost "
			+ "this way.")


class DrainEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := target.player_id
		for land in game.players[victim].battlefield.duplicate():
			if land.is_land() and not land.cur_mana_abilities.is_empty():
				game.tap_for_mana(victim, land)   # a refusal just skips it
		var pool := game.players[victim].mana_pool
		var moved := 0
		for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
				Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
			var n := pool.total_of(color)
			if n > 0:
				game.players[controller].mana_pool.add(color, n)
				moved += n
		pool.clear()
		game.log_line("%s drains %d mana from %s" % [
			game.players[controller].player_name, moved,
			game.players[victim].player_name])

	func describe() -> String:
		return "target player taps out and you take the mana"
