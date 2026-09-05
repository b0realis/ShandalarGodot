extends CardScript
## Gaea's Touch — {G}{G} — Enchantment — (drk, common)
## Oracle: {0}: You may put a basic Forest card from your hand onto the
##         battlefield. Activate only as a sorcery and only once each turn.
##         Sacrifice this enchantment: Add {G}{G}.
##
## Implementation: a second land drop that is not a land drop — the Forest
## arrives through MtgGame.put_from_hand_into_play, so it does not consume the turn's
## land play and it still fires LAND-adjacent statics through the ordinary
## enters-the-battlefield path.
##
## The two riders are engine flags: Illusionary Mask's sorcery-speed
## predicate (your turn, a main phase, an empty stack — CR 307.1) and
## ActivatedAbility.per_turn(1).
##
## The second line is a MANA ability with a sacrifice cost and no tap
## (CR 605.1a), so it needs no priority and can be cashed in mid-payment —
## which is the whole point of a {0} enchantment that eventually becomes
## two green mana.


static func _sorcery_speed(game: MtgGame, source: CardInstance) -> String:
	if game.active_player != source.controller_id \
			or not Mtg.is_main_step(game.current_step()) \
			or not game.stack.is_empty():
		return "activate only as a sorcery"
	return ""


func build() -> CardData:
	return CardData.new("Gaea's Touch", "{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"", false, [PlantEffect.new()],
			"{0}: You may put a basic Forest card from your hand onto the battlefield. Activate only as a sorcery and only once each turn.") \
			.only_if(_sorcery_speed).per_turn(1)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G, 2).without_tap().with_sacrifice()) \
		.oracle("{0}: You may put a basic Forest card from your hand onto the battlefield. "
			+ "Activate only as a sorcery and only once each turn.\n"
			+ "Sacrifice this enchantment: Add {G}{G}.")


class PlantEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var forests: Array[CardInstance] = []
		for card in game.players[controller].hand:
			if card.data.is_land() and card.data.subtypes.has("forest") \
					and (card.data.supertypes & Mtg.Supertype.BASIC) != 0:
				forests.append(card)
		if forests.is_empty():
			return
		if not game.agents[controller].choose_yes_no(game, controller,
				"Put a basic Forest onto the battlefield?", true):
			return
		game.put_from_hand_into_play(forests[0], controller)

	func describe() -> String:
		return "puts a basic Forest from your hand onto the battlefield"
