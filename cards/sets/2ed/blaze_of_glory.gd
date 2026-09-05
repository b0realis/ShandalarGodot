extends CardScript
## Blaze of Glory — {W} — Instant — (2ed, rare)
## Oracle: Cast this spell only during combat before blockers are declared.
##         Target creature defending player controls can block any number
##         of creatures this turn. It blocks each attacking creature this
##         turn if able.
##
## Implementation: both halves. The PERMISSION is
## CardInstance.extra_blocks_this_turn = -1 (any number, CR 509.1b) and the
## ORDER is CardInstance.must_block_this_turn — together they are the
## printed sentence: declare_blockers refuses a declaration that leaves the
## conscript out of ANY block it could legally make. The engine grew
## one-to-many blocks on 2026-09-02 for this card and Two-Headed Giant of
## Foriys; before that the order could only ask for one block.
##
## "DEFENDING PLAYER controls" is a property of the COMBAT, not of the
## caster (CR 506.2): in a duel the defending player is always the active
## player's opponent, whoever cast the spell. So the target filter is
## game-aware — the defending player casting this on their own creature
## (the classic "make my Wall eat the whole team" play) is legal, and the
## attacking player can never aim it at their own attacker.


static func _defending_players_creature(game: MtgGame, inst: CardInstance) -> bool:
	return inst.controller_id == game.opponent_of(game.active_player)


static func _before_blockers(game: MtgGame, _pid: int) -> String:
	if not Mtg.is_combat_step(game.current_step()):
		return "cast Blaze of Glory only during combat"
	if Mtg.STEP_ORDER.find(game.current_step()) \
			> Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS):
		return "cast Blaze of Glory only before blockers are declared"
	return ""


func build() -> CardData:
	var spec := TargetSpec.creature("target creature defending player controls")
	spec.with_game_filter(_defending_players_creature)
	# The filter is about who CONTROLS the creature, so the 1997 refusal
	# word is `controller` rather than the default `type` (§6.10).
	spec.because(TargetSpec.WHY["controller"])
	return CardData.new("Blaze of Glory", "{W}", Mtg.CardType.INSTANT) \
		.castable_only_when(_before_blockers) \
		.spell(BlazeOfGloryEffect.new(spec)) \
		.oracle("Cast this spell only during combat before blockers are declared.\nTarget creature defending player controls can block any number of creatures this turn. It blocks each attacking creature this turn if able.")


class BlazeOfGloryEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var conscript := game.find_instance(target.instance_id)
		if conscript == null or conscript.zone != Mtg.Zone.BATTLEFIELD:
			return
		conscript.must_block_this_turn = true
		# "…can block ANY NUMBER of creatures this turn" — the permission
		# that makes the order above mean every attacker rather than one.
		conscript.extra_blocks_this_turn = -1
		game.log_line("%s can block any number of creatures and must block if able"
			% conscript.data.card_name)

	func describe() -> String:
		return "target creature defending player controls blocks every attacker it can"
