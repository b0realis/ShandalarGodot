extends CardScript
## Damping Field — {2}{W} — Enchantment — (atq, uncommon)
## Oracle: Players can't untap more than one artifact during their untap
##         steps.
##
## Implementation: Smoke's untap cap (MtgGame.cap_untaps), aimed at
## artifacts — Antiquities' answer to a board full of Moxen and mana rocks.
## Symmetric; WHICH artifact untaps is the controller's choice, asked in
## their untap step (`@DAMPING_FIELD`: *"PROCESSING Damping Field: Select
## artifact to untap."*). An artifact creature under this and Smoke counts
## against both caps.


func build() -> CardData:
	return CardData.new("Damping Field", "{2}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Players can't untap more than one artifact during their untap steps.")) \
		.oracle("Players can't untap more than one artifact during their untap steps.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	game.cap_untaps("artifact", 1, source)
