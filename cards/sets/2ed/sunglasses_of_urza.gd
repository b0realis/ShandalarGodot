extends CardScript
## Sunglasses of Urza — {3} — Artifact — (2ed, rare)
## Oracle: You may spend white mana as though it were red mana.
##
## Implementation: a MANA SUBSTITUTION on its controller
## (MtgPlayer.mana_substitutions), rebuilt by the continuous pipeline every
## recalculation, so it vanishes with the Sunglasses. The payment routine
## reaches for the substitute only after real red mana runs out.


func build() -> CardData:
	return CardData.new("Sunglasses of Urza", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_lend_white,
			"You may spend white mana as though it were red mana.")) \
		.oracle("You may spend white mana as though it were red mana.")


static func _lend_white(game: MtgGame, source: CardInstance) -> void:
	game.players[source.controller_id].mana_substitutions.append(
		{"from": Mtg.ManaColor.W, "to": Mtg.ManaColor.R})
