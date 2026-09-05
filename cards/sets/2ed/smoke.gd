extends CardScript
## Smoke — {R}{R} — Enchantment — (2ed, rare)
## Oracle: Players can't untap more than one creature during their untap
##         steps.
##
## Implementation: a static capping the untap step at one creature
## (MtgGame.cap_untaps); WHICH creature untaps is the controller's choice,
## asked in their untap step in the 1997 game's own words (`@SMOKE`:
## *"PROCESSING Smoke: Select creature to untap."*) — a human seat is held
## on it (MtgGame._untap_step), the AI picks its most valuable creature,
## and the default seat takes the first in battlefield order. Symmetric and
## brutal — the classic "nobody attacks any more" prison.


func build() -> CardData:
	return CardData.new("Smoke", "{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(
			_apply,
			"Players can't untap more than one creature during their untap steps.")) \
		.oracle("Players can't untap more than one creature during their untap steps.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	game.cap_untaps("creature", 1, source)
