extends CardScript
## Rebirth — {3}{G}{G}{G} — Sorcery — (4ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         Each player may ante the top card of their library. If a player
##         does, that player's life total becomes 20.
##
## The ransom is a real QUESTION, put to the victim through their own
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself.
##
## Implementation: each player's "may" goes through their DecisionAgent,
## with the hint being "yes if it would actually gain me life" — the only
## reason to pay a card for the reset. The life total is SET to 20, so a
## player above 20 who accepts really loses life.
##
## Not played for ante, it does nothing: the first line is enforced by the
## engine (the owner's ruling of 2026-10-21).
## `MtgGame.not_for_ante_refusal` refuses the cast: "Ante must be on for
## Rebirth: this duel is not played for ante".


func build() -> CardData:
	return CardData.new("Rebirth", "{3}{G}{G}{G}", Mtg.CardType.SORCERY) \
		.spell(RebirthEffect.new()) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\nEach player may ante the top card of their library. If a player does, that player's life total becomes 20.")


class RebirthEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for pid in [controller, game.opponent_of(controller)]:
			var p := game.players[pid]
			if p.has_lost or p.library.is_empty():
				continue
			var hint := p.life < 20
			if not game.agents[pid].choose_yes_no(game, pid,
					"Ante the top card of your library to set your life to 20?", hint):
				continue
			# "If a player DOES": only a card that really went to the ante
			# (MtgGame.ante_top_of_library moves none without ante).
			if game.ante_top_of_library(pid) == null:
				continue
			game.adjust_life(pid, 20 - p.life)

	func describe() -> String:
		return "each player may ante their top card to set their life total to 20"
