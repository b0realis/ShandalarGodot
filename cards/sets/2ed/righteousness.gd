extends CardScript
## Righteousness — {W} — Instant — (2ed, rare)
## Oracle: Target blocking creature gets +7/+7 until end of turn.
##
## Implementation: a PumpEffect whose target spec carries a GAME-AWARE
## filter — only creatures currently declared as blockers qualify (the
## engine's combat.blocks map). White's most explosive combat blowout.


func build() -> CardData:
	var pump := PumpEffect.new(7, 7)
	pump.target_spec = TargetSpec.creature("target blocking creature") \
		.with_game_filter(_is_blocking)
	return CardData.new("Righteousness", "{W}", Mtg.CardType.INSTANT) \
		.spell(pump) \
		.oracle("Target blocking creature gets +7/+7 until end of turn.")


static func _is_blocking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.blocks.has(inst.id)
