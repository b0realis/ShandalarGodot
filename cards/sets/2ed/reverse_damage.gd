extends CardScript
## Reverse Damage — {1}{W}{W} — Instant — (2ed, rare)
## Oracle: The next time a source of your choice would deal damage to you
##         this turn, prevent that damage. You gain life equal to the
##         damage prevented this way.
##
## Implementation: "a source of your choice" — the caster names ONE
## source as the spell resolves (DecisionAgent.choose_card over
## MtgGame.damage_sources, ranked so the first entry is the one about to
## deal damage to them), and a one-shot shield against exactly that
## source goes into MtgPlayer.reverse_damage_sources; MtgGame.deal_damage
## prevents its next damage event whole and pays it back as life. Cast
## with nothing on the table and nothing on the stack, it names nothing
## and does nothing (CR 608.2) — it is cast in RESPONSE to the Bolt.
## `@REVERSE_DAMAGE` (Program/prompts.txt:753) is the original's own
## line for the choice: "Select a card that has damaged you." — its
## first line is the 1997 damage-window click.


func build() -> CardData:
	return CardData.new("Reverse Damage", "{1}{W}{W}", Mtg.CardType.INSTANT) \
		.spell(ReverseDamageEffect.new()) \
		.oracle("The next time a source of your choice would deal damage to you this turn, prevent that damage. You gain life equal to the damage prevented this way.")


class ReverseDamageEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var choices := game.damage_sources(Callable(), TargetRef.player(controller))
		if choices.is_empty():
			game.log_line("Reverse Damage has no source to name")
			return
		var named := game.agents[controller].choose_card(game, controller,
			choices, "Select a card that has damaged you.", false, false, true)
		if named == null or not choices.has(named):
			named = choices[0]
		game.players[controller].reverse_damage_sources.append(named.id)
		game.log_line("%s prepares to turn %s's damage into life" % [
			game.players[controller].player_name, named.data.card_name])

	func describe() -> String:
		return "turns the next damage dealt to you into that much life"
