extends CardScript
## Boris Devilboon — {3}{B}{R} — Legendary Creature — Zombie Wizard — 2/2 — (leg, rare)
## Oracle: {2}{B}{R}, {T}: Create a 1/1 black and red Demon creature token
##         named Minor Demon.
##
## Implementation: a costed tap ability calling MtgGame.create_token with
## a locally-built Minor Demon CardData (given a {B}{R} cost so the token
## really is black AND red — the engine derives colour from mana cost).
## One demon a turn, forever, on a legendary body.


func build() -> CardData:
	return CardData.new("Boris Devilboon", "{3}{B}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["zombie", "wizard"]) \
		.activated(ActivatedAbility.new(
			"{2}{B}{R}", true, [MakeTokenEffect.new(_demon_data())],
			"{2}{B}{R}, {T}: Create a 1/1 black and red Demon creature token named "
			+ "Minor Demon.")) \
		.oracle("{2}{B}{R}, {T}: Create a 1/1 black and red Demon creature token "
			+ "named Minor Demon.")


static func _demon_data() -> CardData:
	return CardData.new("Minor Demon", "", Mtg.CardType.CREATURE) \
		.with_colors(Mtg.ManaColor.B | Mtg.ManaColor.R) \
		.pt(1, 1) \
		.with_subtypes(["demon"]) \
		.oracle("")


class MakeTokenEffect extends EffectBase:
	var token: CardData

	func _init(p_token: CardData) -> void:
		token = p_token

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.create_token(controller, token)

	func describe() -> String:
		return "creates a %s token" % token.card_name
