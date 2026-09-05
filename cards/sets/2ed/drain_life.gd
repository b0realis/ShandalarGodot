extends CardScript
## Drain Life — {X}{1}{B} — Sorcery (2ed, common)
## Oracle: Spend only black mana on X.
##         Drain Life deals X damage to any target. You gain life equal to
##         the damage dealt this way, but not more life than the player's
##         life total before the damage was dealt or the creature's
##         toughness.
##
## Implementation: card-local effect — X damage to any target, then the
## caster gains life equal to the damage ACTUALLY dealt (deal_damage
## reports the post-prevention amount, so a Samite Healer shield shrinks
## the drink), capped by the victim's toughness / life total before the
## damage, exactly as printed. "Spend only black mana on X" is
## CardData.with_colored_x(B): X is paid as black pips (the {1} stays
## generic), so a Drain Life for X=3 costs {1}{B}{B}{B}{B} and a pool short
## of black is refused at cast — the 1997 exe did the same, charging X as
## black (`charge_mana(player, COLOR_BLACK, -1)`, routine 0x41E9B0 in
## `src/cards/unlimited.c`). Lifted 2026-09-02.


func build() -> CardData:
	return CardData.new("Drain Life", "{X}{1}{B}", Mtg.CardType.SORCERY) \
		.with_colored_x(Mtg.ManaColor.B) \
		.spell(DrainEffect.new()) \
		.oracle("Spend only black mana on X.\nDrain Life deals X damage to any target. You gain life equal to the damage dealt this way, but not more life than the player's life total before the damage was dealt or the creature's toughness.")


class DrainEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		if x_value <= 0:
			return
		# Caps read state BEFORE the damage (oracle: "the player's life
		# total before the damage was dealt or the creature's toughness").
		var cap := x_value
		if target.is_player:
			cap = game.players[target.player_id].life
		else:
			var victim := game.find_instance(target.instance_id)
			if victim != null:
				cap = victim.cur_toughness
		# "You gain life equal to the damage dealt this way" is answered
		# WHEN THE DAMAGE LANDS, not when it is planned: under the 1997
		# damage-prevention window (docs/duel-todo.md §6.8) the answer is
		# not known until the step ends. With no window open the callback
		# runs inside deal_damage and nothing has changed.
		game.deal_damage(source, target, x_value, false,
			func(dealt: int) -> void:
				var gain: int = mini(dealt, cap)
				if gain > 0:
					game.adjust_life(controller, gain))

	func describe() -> String:
		return "deals X damage to any target; you gain that much life"
