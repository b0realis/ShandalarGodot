extends CardScript
## Aladdin's Lamp — {10} — Artifact — (4ed, rare)
## Oracle: {X}, {T}: The next time you would draw a card this turn, instead
##         look at the top X cards of your library, put all but one of them
##         on the bottom of your library in a random order, then draw a
##         card. X can't be 0.
##
## Implementation: a ONE-SHOT CR 614 replacement, registered on the game by
## the resolving ability (MtgGame.replace_next_draw) and consumed by the
## next draw it catches — including a draw that is not yours to expect, like
## the one an opponent's Howling Mine hands you. Unspent, it expires at
## cleanup, because the printed clause says "this turn".
##
## "X can't be 0" is a real REFUSAL (ActivatedAbility.with_min_x), not a
## silent clamp: naming an illegal X is a player-level mistake and the
## engine says so rather than guessing.
##
## The card kept is the player's choice — `@ALADDINS_LAMP`,
## `Program/prompts.txt:1`, is `Select a card to put in your hand.`, which
## is the original describing this exact ability. The others go to the
## BOTTOM in a RANDOM order (through game.rng, so a seeded duel replays),
## and the kept card is then simply the top of the library, which the
## following draw takes.
##
## The lamp's own "then draw a card" is a NEW draw event, so a Chains of
## Mephistopheles on the table still catches it — which is correct, and the
## reason the replacement is consumed before the draw is made.


func build() -> CardData:
	return CardData.new("Aladdin's Lamp", "{10}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{X}", true, [LampEffect.new()],
			"{X}, {T}: The next time you would draw a card this turn, instead look "
			+ "at the top X cards of your library, put all but one of them on the "
			+ "bottom in a random order, then draw a card.") \
			.with_min_x(1)) \
		.oracle("{X}, {T}: The next time you would draw a card this turn, instead "
			+ "look at the top X cards of your library, put all but one of them on "
			+ "the bottom of your library in a random order, then draw a card. "
			+ "X can't be 0.")


class LampEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		if x_value <= 0:
			return
		game.replace_next_draw(controller, LampEffect._rummage.bind(x_value))

	## The replacement itself: look at X, keep one, bury the rest, draw.
	static func _rummage(game: MtgGame, pid: int, _ctx: Dictionary,
			x: int) -> void:
		var library := game.players[pid].library
		var top: Array[CardInstance] = []
		for i in mini(x, library.size()):
			top.append(library[library.size() - 1 - i])
		if top.is_empty():
			return   # an empty library: the draw is still replaced away
		# The default agent takes candidates[0], so offer the biggest first.
		top.sort_custom(LampEffect._pricier_first)
		# `@ALADDINS_LAMP` entry 1, Program/prompts.txt:3.
		var keep := game.agents[pid].choose_card(game, pid, top,
			"Select a card to put in your hand.")
		if keep == null or not top.has(keep):
			keep = top[0]
		var rest: Array = []
		for inst in top:
			if inst != keep:
				rest.append(inst)
		# "in a random order" — sample() drains the list in random order.
		for inst in RandomEffects.sample(game, rest, rest.size()):
			game.put_on_bottom_of_library(inst)
		game.log_line("Aladdin's Lamp keeps %s and buries %d card(s)" % [
			keep.data.card_name, rest.size()])
		# The kept card is now the top of the library.
		game.draw_cards(pid, 1)

	static func _pricier_first(a: CardInstance, b: CardInstance) -> bool:
		var av := a.data.cost.mana_value()
		var bv := b.data.cost.mana_value()
		if av != bv:
			return av > bv
		return a.id < b.id

	func describe() -> String:
		return "the next card you would draw this turn is dug for instead"
