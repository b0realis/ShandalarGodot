extends CardScript
## Darkpact — {B}{B}{B} — Sorcery — (2ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         You own target card in the ante. Exchange that card with the top
##         card of your library.
##
## Implementation: both sentences, in order. The targeted ante card becomes
## YOURS (a permanent change of ownership — the thing that outlives the
## duel), then it swaps places with your library's top card: the ante card
## goes on top of your library, and that card goes into the ante. Casting
## it with an empty library does nothing but the ownership grab.


func build() -> CardData:
	return CardData.new("Darkpact", "{B}{B}{B}", Mtg.CardType.SORCERY) \
		.spell(DarkpactEffect.new(TargetSpec.new(TargetSpec.Kind.CARD_IN_ANTE))) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\nYou own target card in the ante. Exchange that card with the top card of your library.")


class DarkpactEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var staked := game.find_instance(target.instance_id)
		if staked == null or staked.zone != Mtg.Zone.ANTE:
			return
		game.change_owner(staked, controller)
		if game.players[controller].library.is_empty():
			return
		var top: CardInstance = game.players[controller].library.back()
		game.move_to_ante(top)
		game.remove_from_ante(staked, Mtg.Zone.LIBRARY)

	func describe() -> String:
		return "you own target card in the ante; exchange it with the top card of your library"
