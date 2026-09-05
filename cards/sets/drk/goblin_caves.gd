extends CardScript
## Goblin Caves — {1}{R}{R} — Enchantment — Aura — (drk, common)
## Oracle: Enchant land
##         As long as enchanted land is a basic Mountain, Goblin creatures
##         get +0/+2.
##
## Implementation: an anthem gated on what its HOST is. "Basic Mountain"
## needs both halves: the BASIC supertype (printed — nothing in this pool
## grants it, and CR 305.7 retyping a land does not either, so a Blood
## Moon'd Karakas is a Mountain but not a basic one) and the live "mountain"
## subtype, which a Magical Hack can take away. The anthem is unrestricted
## — "Goblin creatures", not "Goblin creatures you control" — so it also
## toughens the opponent's Goblins.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Goblin Caves", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.static_ability(StaticAbility.new(
			_shelter, "As long as enchanted land is a basic Mountain, Goblin creatures get +0/+2.")) \
		.oracle("Enchant land\n"
			+ "As long as enchanted land is a basic Mountain, Goblin creatures get +0/+2.")


## Is the host a BASIC MOUNTAIN right now? Supertype off the printed card
## (no effect in this pool grants "basic"), subtype off the live list.
static func _on_a_basic_mountain(game: MtgGame, source: CardInstance) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and (host.data.supertypes & Mtg.Supertype.BASIC) != 0 \
		and host.has_subtype("mountain")


static func _shelter(game: MtgGame, source: CardInstance) -> void:
	if not _on_a_basic_mountain(game, source):
		return
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.has_subtype("goblin"):
			inst.cur_toughness += 2
