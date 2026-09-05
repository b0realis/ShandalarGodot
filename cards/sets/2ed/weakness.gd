extends CardScript
## Weakness — {B} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. Enchanted creature gets -2/-1.
##
## Implementation: the NEGATIVE aura — same pattern as unholy_strength.gd
## with a downside. Interesting engine consequence the tests pin: shrinking
## a 2/1 (Savannah Lions) to 0/0 kills it via the toughness<=0 state-based
## action (CR 704.5f) — a death regeneration cannot prevent.


func build() -> CardData:
	return CardData.new("Weakness", "{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets -2/-1.")) \
		.oracle("Enchant creature. Enchanted creature gets -2/-1.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_power -= 2
	host.cur_toughness -= 1
