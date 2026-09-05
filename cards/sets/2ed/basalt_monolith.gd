extends CardScript
## Basalt Monolith — {3} — Artifact — (2ed, uncommon)
## Oracle: This artifact doesn't untap during your untap step.
##         {T}: Add {C}{C}{C}.
##         {3}: Untap this artifact.
##
## Implementation: Mana Vault's bigger sibling — cur_skips_untap static,
## a {C}{C}{C} mana ability, and a {3} activated self-untap (net +0, so
## no loop pays for itself — matching the printed card's math).


func build() -> CardData:
	return CardData.new("Basalt Monolith", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_lock, "This artifact doesn't untap during your untap step.")) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 3)) \
		.activated(ActivatedAbility.new(
			"{3}", false,
			[UntapSelfEffect.new()],
			"{3}: Untap this artifact.")) \
		.oracle("This artifact doesn't untap during your untap step.\n{T}: Add {C}{C}{C}.\n{3}: Untap this artifact.")


static func _lock(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


class UntapSelfEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.untap_permanent(source)

	func describe() -> String:
		return "untaps this artifact"
