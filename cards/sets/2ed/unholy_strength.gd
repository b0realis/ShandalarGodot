extends CardScript
## Unholy Strength — {B} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. Enchanted creature gets +2/+1.
##
## Implementation: same aura pattern as holy_strength.gd (which carries the
## full pattern notes) — attach on resolve, static +2/+1 while attached,
## SBA sweeps it when the host leaves. Note it cannot enchant White Knight
## (protection from black covers Enchanted — the E of DEBT).


func build() -> CardData:
	return CardData.new("Unholy Strength", "{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +2/+1.")) \
		.oracle("Enchant creature. Enchanted creature gets +2/+1.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_power += 2
	host.cur_toughness += 1
