extends CardScript
## Lance — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant creature
##         Enchanted creature has first strike.
##
## Implementation: the keyword-granting aura pattern (see flight.gd) in
## first-strike flavor — combat's two-wave damage reads cur_keywords, so
## the host immediately strikes first.


func build() -> CardData:
	return CardData.new("Lance", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature has first strike.")) \
		.oracle("Enchant creature\nEnchanted creature has first strike.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD \
			and not host.cur_keywords.has(Mtg.Keyword.FIRST_STRIKE):
		host.cur_keywords.append(Mtg.Keyword.FIRST_STRIKE)
