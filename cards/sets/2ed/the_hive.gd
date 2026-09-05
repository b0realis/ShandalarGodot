extends CardScript
## The Hive — {5} — Artifact — (2ed, rare)
## Oracle: {5}, {T}: Create a 1/1 colorless Insect artifact creature token
##         with flying named Wasp.
##
## Implementation: a costed tap ability calling MtgGame.create_token with
## a locally-built CardData for the Wasp. Ten mana for the first wasp is
## a joke by modern standards; in 1994 it was an inevitable win condition
## that no sorcery-speed removal could answer.


func build() -> CardData:
	return CardData.new("The Hive", "{5}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{5}", true, [MakeTokenEffect.new(_wasp_data())],
			"{5}, {T}: Create a 1/1 colorless Insect artifact creature token with "
			+ "flying named Wasp.")) \
		.oracle("{5}, {T}: Create a 1/1 colorless Insect artifact creature token with "
			+ "flying named Wasp. (It can't be blocked except by creatures with flying "
			+ "or reach.)")


static func _wasp_data() -> CardData:
	return CardData.new("Wasp", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["insect"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.oracle("Flying")


class MakeTokenEffect extends EffectBase:
	var token: CardData

	func _init(p_token: CardData) -> void:
		token = p_token

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.create_token(controller, token)

	func describe() -> String:
		return "creates a %s token" % token.card_name
