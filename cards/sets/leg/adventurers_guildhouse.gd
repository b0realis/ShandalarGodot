extends CardScript
## Adventurers' Guildhouse — Land — (leg, uncommon)
## Oracle: Green legendary creatures you control have "bands with
##         other legendary creatures."
##
## Implementation (lifted 2026-09-02; was "Banding lands and bands-with
## cycles" in docs/simplified-cards.md): a static granting the
## controller's green legendary creatures "bands with other
## legendary creatures" — CardInstance.grant_bands_with, the second form
## of CR 702.22c, NOT the banding keyword. So a legend under this land
## may lead a band of any number of other legendary creatures (whether
## or not they have banding), may not band with a non-legend at all
## unless a banding creature's own band takes it as the one member
## without banding, and two such legends blocking the same creature hand
## its damage division to the defender (CR 702.22j). Losing banding
## (Tolaria, Shelkin Brownie) strips this as well (CR 702.22b). Not a
## 1997 card (no Duel.hlp entry, no exe function in Magic-trace.c);
## mage-go approximates the ability as plain banding ("XXX" in
## cards/legends/lands.go), which is what this file did until the lift.


func build() -> CardData:
	return CardData.new("Adventurers' Guildhouse", "", Mtg.CardType.LAND) \
		.static_ability(StaticAbility.new(
			_apply,
			"Green legendary creatures you control have bands with other "
			+ "legendary creatures.")) \
		.oracle("Green legendary creatures you control have \"bands with other "
			+ "legendary creatures.\"")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.controller_id != source.controller_id or not inst.is_creature():
			continue
		if not _is_legendary(inst):
			continue
		if (inst.cur_colors & Mtg.ManaColor.G) == 0:
			continue
		inst.grant_bands_with("legendary creatures", _is_legendary)


## The quality: "other legendary creatures".
static func _is_legendary(inst: CardInstance) -> bool:
	return inst.is_creature() and (inst.data.supertypes & Mtg.Supertype.LEGENDARY) != 0
