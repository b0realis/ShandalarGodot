extends CardScript
## Mana Short — {2}{U} — Instant — (2ed, rare)
## Oracle: Tap all lands target player controls and that player loses all
##         unspent mana.
##
## Implementation: both halves, in the printed order — the taps happen
## first (so tap triggers like City of Brass's fire), then the pool is
## emptied, which is what makes Mana Short a real counterspell against a
## player who floated mana in response.


func build() -> CardData:
	return CardData.new("Mana Short", "{2}{U}", Mtg.CardType.INSTANT) \
		.spell(ManaShortEffect.new()) \
		.oracle("Tap all lands target player controls and that player loses all unspent mana.")


class ManaShortEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		for inst in game.players[pid].battlefield.duplicate():
			if inst.is_land() and not inst.tapped:
				game.tap_permanent(inst)
		game.players[pid].mana_pool.clear()
		game.log_line("%s loses all unspent mana" % game.players[pid].player_name)

	func describe() -> String:
		return "taps all of target player's lands and empties their mana pool"
