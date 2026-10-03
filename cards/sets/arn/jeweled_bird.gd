extends CardScript
## Jeweled Bird — {1} — Artifact — (arn, uncommon)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         {T}: Ante this artifact. If you do, put all other cards you own
##         from the ante into your graveyard, then draw a card.
##
## Implementation: the Bird trades your whole stake for one card — it goes
## into the ante itself, and every OTHER card you own there goes to your
## graveyard, so the opponent's stake is untouched. Because the Bird taps
## as a cost and antes as an effect, an opponent can respond to the
## activation, exactly as printed.


func build() -> CardData:
	return CardData.new("Jeweled Bird", "{1}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", true, [BirdEffect.new()],
			"{T}: Ante this artifact. If you do, put all other cards you own from the ante into your graveyard, then draw a card.")) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\n{T}: Ante this artifact. If you do, put all other cards you own from the ante into your graveyard, then draw a card.")


class BirdEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# Phased out: it can't be anted, so "if you do" fails (CR 702.26b) —
		# and move_to_ante would lift it out of its phased-out state.
		if not game.is_present(source):
			return
		game.move_to_ante(source)
		# "all other cards YOU OWN" — you is the ACTIVATOR, not the Bird's
		# owner, and a card sits in the ante array of the player who owns
		# it. A Bird an opponent has stolen dumps THEIR stake, not yours.
		# Snapshot first: remove_from_ante mutates that ante array.
		var mine: Array = []
		for inst in game.players[controller].ante:
			if inst != source:
				mine.append(inst)
		for inst in mine:
			game.remove_from_ante(inst, Mtg.Zone.GRAVEYARD)
		game.draw_cards(controller, 1)

	func describe() -> String:
		return "antes itself, dumps your other ante cards, and draws a card"
