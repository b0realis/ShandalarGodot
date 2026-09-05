extends CardScript
## Reset — {U}{U} — Instant — (leg, uncommon)
## Oracle: Cast this spell only during an opponent's turn after their
##         upkeep step. Untap all lands you control.
##
## Implementation: a card-local sweep untapping every land its caster
## controls, gated by CardData.castable_only_when. The printed rider is
## load-bearing: without it Reset is a RITUAL — tap N lands for mana in
## your own main phase, spend {U}{U} on Reset, untap all N for a net of
## N-2 free mana. Enforced as "an opponent's turn, past their upkeep".


func build() -> CardData:
	return CardData.new("Reset", "{U}{U}", Mtg.CardType.INSTANT) \
		.castable_only_when(_after_their_upkeep) \
		.spell(ResetEffect.new()) \
		.oracle("Cast this spell only during an opponent's turn after their upkeep "
			+ "step. Untap all lands you control.")


static func _after_their_upkeep(game: MtgGame, pid: int) -> String:
	if game.active_player == pid:
		return "cast Reset only during an opponent's turn"
	if Mtg.STEP_ORDER.find(game.current_step()) \
			<= Mtg.STEP_ORDER.find(Mtg.Step.UPKEEP):
		return "cast Reset only after their upkeep step"
	return ""


class ResetEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for inst in game.players[controller].battlefield:
			if inst.is_land():
				game.untap_permanent(inst)

	func describe() -> String:
		return "untaps all lands you control"
