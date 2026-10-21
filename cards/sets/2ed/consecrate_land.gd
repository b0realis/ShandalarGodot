extends CardScript
## Consecrate Land — {W} — Enchantment — Aura — (2ed, uncommon)
## Oracle: Enchant land
##         Enchanted land has indestructible and can't be enchanted by
##         other Auras.
##
## Implementation: both clauses are live instance flags the continuous
## pipeline rebuilds — cur_indestructible (new in this wave: destruction
## and lethal damage simply do nothing, CR 700.4) and the
## cur_cant_be_aura_target ban Anti-Magic Aura already uses.
##
## "Can't be enchanted by other Auras" also makes an Aura ALREADY on the
## land illegal (CR 303.4d), so the state-based check puts it into its
## owner's graveyard (CR 704.5m): the Consecrate Land names itself in
## cur_other_auras_barred_by, which MtgGame.aura_can_enchant reads. Until
## the bug hunt of 2026-10-21 only a new Aura was kept off — an Evil
## Presence already there went on making the Forest a Swamp.


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


func build() -> CardData:
	return CardData.new("Consecrate Land", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.static_ability(StaticAbility.new(_bless,
			"Enchanted land has indestructible and can't be enchanted by other Auras.")) \
		.oracle("Enchant land\nEnchanted land has indestructible and can't be enchanted by other Auras.")


static func _bless(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_indestructible = true
	host.cur_cant_be_aura_target = true
	host.cur_other_auras_barred_by.append(source.id)
