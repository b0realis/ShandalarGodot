extends CardScript
## Winter Orb — {2} — Artifact — (2ed, rare)
## Oracle: As long as this artifact is untapped, players can't untap more
##         than one land during their untap steps.
##
## Implementation: Smoke's untap cap on lands (MtgGame.cap_untaps), gated
## on the Orb itself being untapped — which is why Icy Manipulator (or a
## tap ability of your own) was the standard way to play around your own
## Orb. WHICH land untaps is the controller's choice, asked in their untap
## step (`@WINTERORB`: *"PROCESSING Winter Orb: Select land to untap."*).


func build() -> CardData:
	return CardData.new("Winter Orb", "{2}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_apply,
			"As long as Winter Orb is untapped, players can't untap more than one "
			+ "land during their untap steps.")) \
		.oracle("As long as this artifact is untapped, players can't untap more than "
			+ "one land during their untap steps.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if not source.tapped:
		game.cap_untaps("land", 1, source)
