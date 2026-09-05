extends CardScript
## Chain Lightning — {R} — Sorcery — (leg, common)
## Oracle: Chain Lightning deals 3 damage to any target. Then that player
##         or that permanent's controller may pay {R}{R}. If the player
##         does, they may copy this spell and may choose a new target for
##         that copy.
##
## Implementation: both halves. The victim (the targeted player, or the
## targeted permanent's controller) is offered the {R}{R} through the
## triggered-payment path — floating mana first, then auto-tapped lands —
## and paying puts a real copy of Chain Lightning on the stack under THEIR
## control, aimed back at the player who fired it. That is the chain.
##
## "May choose a new target for that copy" (CR 707.10c) is the payer's
## choice, made as the copy is put on the stack (MtgGame.offer_new_targets)
## from every legal "any target" right now; the list leads with the
## previous caster's face — the reason anyone pays, and the heuristic's
## answer — and the original's target follows. mage-go (Tier 3) does not
## implement the chain at all; this is the printed card.


func build() -> CardData:
	return CardData.new("Chain Lightning", "{R}", Mtg.CardType.SORCERY) \
		.spell(ChainEffect.new()) \
		.oracle("Chain Lightning deals 3 damage to any target. Then that player or "
			+ "that permanent's controller may pay {R}{R}. If the player does, they "
			+ "may copy this spell and may choose a new target for that copy.")


class ChainEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.deal_damage(source, target, 3)
		# Who gets the option: the targeted player, or the targeted
		# permanent's controller.
		var victim := -1
		if target.is_player:
			victim = target.player_id
		else:
			var hit := game.find_instance(target.instance_id)
			if hit != null:
				victim = hit.controller_id
		if victim < 0 or game.players[victim].has_lost:
			return
		var rent := ManaCost.parse("{R}{R}")
		if not game.can_afford_cost(victim, rent):
			return
		if not game.agents[victim].choose_yes_no(game, victim,
				"Pay {R}{R} to copy Chain Lightning?", true):
			return
		if not game.try_pay(victim, rent):
			return
		var copy := game.copy_spell_on_stack(source, victim)
		if copy != null:
			game.offer_new_targets(copy, victim, controller)

	func describe() -> String:
		return "deals 3 damage to any target; the victim may pay {R}{R} to copy it"
