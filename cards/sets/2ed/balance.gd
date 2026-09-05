extends CardScript
## Balance — {1}{W} — Sorcery — (2ed, rare)
## Oracle: Each player chooses a number of lands they control equal to the
##         number of lands controlled by the player who controls the fewest,
##         then sacrifices the rest. Players discard cards and sacrifice
##         creatures the same way.
##
## Implementation: three passes in the printed order — lands, then hands,
## then creatures. Each pass measures its own minimum across the seats and
## each player over that minimum gives up the difference. What goes is the
## PLAYER's choice, asked one card at a time through the DecisionAgent
## funnel, and the 1997 game asked the same two questions: `@BALANCE`
## (`Program/prompts.txt:81`) is two prompts, `Sacrifice land.` and
## `Sacrifice creature you control.` — the third pass is the ordinary
## discard prompt.
##
## The choices go round in APNAP order (CR 101.4), and each pass counts
## FRESH: the printed "then" is sequential, so an animated land sacrificed
## in the land pass is not still around to be counted as a creature.
##
## Sacrifice, not destruction (CR 701.17): regeneration and indestructible
## do not save anything here.
##
## mage-go implements Balance too (pkg/mage/effect_removal.go), but its
## version sacrifices the FIRST matching permanent it finds and only asks
## about the discard; the 1997 prompts are the reason ours asks about all
## three.


func build() -> CardData:
	return CardData.new("Balance", "{1}{W}", Mtg.CardType.SORCERY) \
		.spell(BalanceEffect.new()) \
		.oracle("Each player chooses a number of lands they control equal to the "
			+ "number of lands controlled by the player who controls the fewest, "
			+ "then sacrifices the rest. Players discard cards and sacrifice "
			+ "creatures the same way.")


class BalanceEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# `@BALANCE` entry 1 — the original's own words.
		_level(game, BalanceEffect._is_land, "Sacrifice land.")
		_discard_level(game)
		# `@BALANCE` entry 2.
		_level(game, BalanceEffect._is_creature, "Sacrifice creature you control.")

	static func _is_land(inst: CardInstance) -> bool:
		return inst.is_land()

	static func _is_creature(inst: CardInstance) -> bool:
		return inst.is_creature()

	## APNAP (CR 101.4): the active player answers first.
	static func _seats(game: MtgGame) -> Array[int]:
		var out: Array[int] = [game.active_player, game.opponent_of(game.active_player)]
		return out

	## One "sacrifice down to the smallest board" pass over [param matches].
	static func _level(game: MtgGame, matches: Callable, prompt: String) -> void:
		var owned: Dictionary = {}
		var fewest := -1
		for pid in _seats(game):
			var mine: Array[CardInstance] = []
			for inst in game.players[pid].battlefield:
				if matches.call(inst):
					mine.append(inst)
			owned[pid] = mine
			if fewest < 0 or mine.size() < fewest:
				fewest = mine.size()
		for pid in _seats(game):
			var mine: Array = owned[pid]
			var give := mine.size() - fewest
			for _i in give:
				# Re-read the board each time: the last pick may have taken
				# an Aura's host, or a land that was propping something up.
				var live: Array[CardInstance] = []
				for inst in game.players[pid].battlefield:
					if matches.call(inst):
						live.append(inst)
				if live.is_empty():
					break
				live.sort_custom(BalanceEffect._cheapest_first)
				var pick := game.agents[pid].choose_card(game, pid, live, prompt)
				if pick == null or not live.has(pick):
					pick = live[0]
				game.sacrifice_permanent(pick)

	## The same pass over HANDS, which discard rather than sacrifice.
	static func _discard_level(game: MtgGame) -> void:
		var fewest := -1
		for pid in _seats(game):
			var n := game.players[pid].hand.size()
			if fewest < 0 or n < fewest:
				fewest = n
		for pid in _seats(game):
			var over := game.players[pid].hand.size() - fewest
			if over <= 0:
				continue
			game.discard_cards(pid, game.agents[pid].choose_discard(game, pid, over))

	## The default agent takes candidates[0], so the cheapest body — the one
	## a player would give up first — is offered first.
	static func _cheapest_first(a: CardInstance, b: CardInstance) -> bool:
		var av := a.cur_power + a.cur_toughness + a.data.cost.mana_value()
		var bv := b.cur_power + b.cur_toughness + b.data.cost.mana_value()
		if av != bv:
			return av < bv
		return a.id < b.id

	func describe() -> String:
		return "every player levels down to the smallest board, hand and army"
