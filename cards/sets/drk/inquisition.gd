extends CardScript
## Inquisition — {2}{B} — Sorcery — (drk, common)
## Oracle: Target player reveals their hand. Inquisition deals damage to
##         that player equal to the number of white cards in their hand.
##
## Implementation: card-local — log the reveal, count white cards (color
## from mana cost), deal that much damage (a black source).


func build() -> CardData:
	return CardData.new("Inquisition", "{2}{B}", Mtg.CardType.SORCERY) \
		.spell(InquisitionEffect.new()) \
		.oracle("Target player reveals their hand. Inquisition deals damage to that player equal to the number of white cards in their hand.")


class InquisitionEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var p := game.players[target.player_id]
		var names := PackedStringArray()
		var white := 0
		for inst in p.hand:
			names.append(inst.data.card_name)
			if (inst.cur_colors & Mtg.ManaColor.W) != 0:
				white += 1
		game.log_line("%s reveals: %s" % [p.player_name, ", ".join(names)])
		game.deal_damage(source, target, white)

	func describe() -> String:
		return "damage equal to the white cards in target player's hand"
