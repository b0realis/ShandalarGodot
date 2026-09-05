extends CardScript
## Flight — {U} — Enchantment — Aura (2ed, common)
## Oracle: Enchant creature. Enchanted creature has flying.
##
## Implementation: the KEYWORD-GRANTING aura pattern — the static ability
## appends FLYING to the host's live keywords on every recalculation.
## Because combat legality reads cur_keywords, the host immediately flies
## over ground blockers (and can block flyers).


func build() -> CardData:
	return CardData.new("Flight", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature has flying.")) \
		.oracle("Enchant creature. Enchanted creature has flying.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	if not host.cur_keywords.has(Mtg.Keyword.FLYING):
		host.cur_keywords.append(Mtg.Keyword.FLYING)
