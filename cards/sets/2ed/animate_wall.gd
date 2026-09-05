extends CardScript
## Animate Wall — {W} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant Wall
##         Enchanted Wall can attack as though it didn't have defender.
##
## Implementation: the static strips DEFENDER from the host's live
## keywords — in this pool nothing else reads DEFENDER but the attack
## check, so removal IS "as though" (revisit if a defender-matters card
## ever graduates).


func build() -> CardData:
	var wall_spec := TargetSpec.creature("target Wall", _is_wall).only_walls()
	return CardData.new("Animate Wall", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(wall_spec) \
		.static_ability(StaticAbility.new(
			_liberate, "Enchanted Wall can attack as though it didn't have defender.")) \
		.oracle("Enchant Wall\nEnchanted Wall can attack as though it didn't have defender.")


static func _is_wall(inst: CardInstance) -> bool:
	return inst.has_subtype("wall")


static func _liberate(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_keywords.erase(Mtg.Keyword.DEFENDER)
