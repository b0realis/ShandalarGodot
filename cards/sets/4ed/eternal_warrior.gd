extends CardScript
## Eternal Warrior — {R} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Enchanted creature has vigilance.
##
## Implementation: keyword-granting aura (flight.gd pattern) — vigilance,
## so the host attacks without tapping (checked in declare_attackers).


func build() -> CardData:
	return CardData.new("Eternal Warrior", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature has vigilance.")) \
		.oracle("Enchant creature\nEnchanted creature has vigilance.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD \
			and not host.cur_keywords.has(Mtg.Keyword.VIGILANCE):
		host.cur_keywords.append(Mtg.Keyword.VIGILANCE)
