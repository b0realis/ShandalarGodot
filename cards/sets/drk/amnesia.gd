extends CardScript
## Amnesia — {3}{U}{U}{U} — Sorcery — (drk, uncommon)
## Oracle: Target player reveals their hand and discards all nonland cards.
##
## Implementation: card-local — collect the target player's nonland hand
## cards (logged as the "reveal") and discard them all. Devastating
## against a stocked hand, dead against topdeck mode.


func build() -> CardData:
	return CardData.new("Amnesia", "{3}{U}{U}{U}", Mtg.CardType.SORCERY) \
		.spell(AmnesiaEffect.new()) \
		.oracle("Target player reveals their hand and discards all nonland cards.")


class AmnesiaEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var p := game.players[target.player_id]
		var names := PackedStringArray()
		for inst in p.hand:
			names.append(inst.data.card_name)
		game.log_line("%s reveals: %s" % [p.player_name, ", ".join(names)])
		var nonlands: Array = []
		for inst in p.hand:
			if not inst.data.is_land():
				nonlands.append(inst)
		game.discard_cards(target.player_id, nonlands)

	func describe() -> String:
		return "target player reveals their hand and discards all nonland cards"
