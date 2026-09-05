extends CardScript
## Lure — {1}{G}{G} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         All creatures able to block enchanted creature do so.
##
## Implementation: a static raising the host's cur_must_be_blocked flag;
## MtgGame.declare_blockers refuses any declaration that leaves an
## untapped creature at home when it could legally have blocked the
## lured attacker (CR 509.1c). On a trampler or a deathtouch-ish body it
## eats the defender's whole board.


func build() -> CardData:
	return CardData.new("Lure", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "All creatures able to block enchanted creature do so.")) \
		.oracle("Enchant creature\nAll creatures able to block enchanted creature do so.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_must_be_blocked = true
