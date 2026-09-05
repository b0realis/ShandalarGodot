extends CardScript
## Illusionary Mask — {2} — Artifact — (2ed, rare)
## Oracle: {X}: You may choose a creature card in your hand whose mana cost
##         could be paid by some amount of, or all of, the mana you spent on
##         {X}. If you do, you may cast that card face down as a 2/2
##         creature spell without paying its mana cost. If the creature that
##         spell becomes as it resolves has not been turned face up and
##         would assign or deal damage, be dealt damage, or become tapped,
##         instead it's turned face up and assigns or deals damage, is dealt
##         damage, or becomes tapped. Activate only as a sorcery.
##
## Implementation: real FACE-DOWN permanents (CardInstance.face_down) — a
## 2/2 colourless creature with no name, no other types and no abilities
## until something turns it up. MtgGame turns it face up the moment it
## would deal damage, be dealt damage or become tapped, which is exactly
## the printed replacement.
##
## "Activate only as a sorcery" is the full sorcery-timing test (CR 307.1,
## via CR 117.1a): the source controller's own turn, a MAIN phase, and an
## empty stack. Pinning it to MAIN1 instead would both allow the
## opponent's precombat main and forbid your own second main.
##
## SIMPLIFIED (docs/simplified-cards.md, "Illusionary Mask"): the creature
## goes straight onto the battlefield face down rather than being cast as a
## face-down spell (nothing in the pool can counter it either way), and
## WHICH creature is masked is the DecisionAgent's pick — the most
## expensive one X can cover, which is the whole point of the card.


## "Activate only as a sorcery" (CR 307.1): your turn, a main phase,
## nothing on the stack. Returns "" when that holds, a refusal otherwise.
static func _sorcery_speed(game: MtgGame, source: CardInstance) -> String:
	if game.active_player != source.controller_id \
			or not Mtg.is_main_step(game.current_step()) \
			or not game.stack.is_empty():
		return "activate only as a sorcery"
	return ""


func build() -> CardData:
	return CardData.new("Illusionary Mask", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{X}", false, [MaskEffect.new()],
			"{X}: Put a creature card from your hand with mana value X or less onto the battlefield face down as a 2/2.") \
			.only_if(_sorcery_speed)) \
		.oracle("{X}: You may choose a creature card in your hand whose mana cost could be paid by some amount of, or all of, the mana you spent on {X}. If you do, you may cast that card face down as a 2/2 creature spell without paying its mana cost. If the creature that spell becomes as it resolves has not been turned face up and would assign or deal damage, be dealt damage, or become tapped, instead it's turned face up and assigns or deals damage, is dealt damage, or becomes tapped. Activate only as a sorcery.")


class MaskEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		var candidates: Array[CardInstance] = []
		for card in game.players[controller].hand:
			if card.data.is_creature() and card.data.cost.mana_value() <= x_value:
				candidates.append(card)
		if candidates.is_empty():
			game.log_line("Illusionary Mask finds nothing to hide")
			return
		candidates.sort_custom(MaskEffect._pricier_first)
		var chosen := game.agents[controller].choose_card(game, controller,
			candidates, "Put a creature onto the battlefield face down")
		if chosen == null or not candidates.has(chosen):
			chosen = candidates[0]
		game.put_from_hand_face_down(chosen, controller)

	static func _pricier_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value()

	func describe() -> String:
		return "puts a masked creature onto the battlefield as a 2/2"
