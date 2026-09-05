extends CardScript
## Spectral Cloak — {U}{U} — Enchantment — Aura — (leg, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has shroud as long as it's untapped.
##
## Implementation: a static raising the host's SHROUD flag while it is
## untapped — TargetSpec then refuses every source, spells and abilities
## alike (that is what shroud means, unlike Anti-Magic Aura's
## spells-only ban). Attacking taps the host, which is exactly when the
## opponent gets their window.


func build() -> CardData:
	return CardData.new("Spectral Cloak", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted creature has shroud as long as it's untapped.")) \
		.oracle("Enchant creature\nEnchanted creature has shroud as long as it's "
			+ "untapped. (It can't be the target of spells or abilities.)")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD and not host.tapped:
		host.cur_shroud = true
