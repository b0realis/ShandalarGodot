extends CardScript
## Master of the Hunt — {2}{G}{G} — Creature — Human — 2/2 — (leg, rare)
## Oracle: {2}{G}{G}: Create a 1/1 green Wolf creature token named Wolves
##         of the Hunt. It has "bands with other creatures named Wolves of
##         the Hunt." (Any creatures named Wolves of the Hunt can attack in
##         a band as long as at least one has "bands with other creatures
##         named Wolves of the Hunt." Bands are blocked as a group. If at
##         least two creatures named Wolves of the Hunt you control, one of
##         which has "bands with other creatures named Wolves of the Hunt,"
##         are blocking or being blocked by the same creature, you divide
##         that creature's combat damage, not its controller, among any of
##         the creatures it's being blocked by or is blocking.)
##
## Implementation (lifted 2026-09-02; was "Banding lands and bands-with
## cycles" in docs/simplified-cards.md): a tapless four-mana token maker —
## no {T}, so with enough mana the whole pack arrives in one turn. Each
## Wolf carries a static that grants ITSELF "bands with other creatures
## named Wolves of the Hunt" (CardInstance.grant_bands_with — the second
## form of CR 702.22c), NOT the banding keyword it used to be given. So
## any number of Wolves attack as one band; a Wolf may not band with the
## Master, who is no Wolf; a Wolf that joins a banding creature's band is
## just that band's one member without banding (first form); and two
## Wolves blocking the same attacker hand its damage division to the
## DEFENDER (CR 702.22j). Losing banding takes the pack ability with it
## (CR 702.22b — Tolaria). Not a 1997 card (no Duel.hlp entry, no exe
## function in Magic-trace.c); Manalink's card_master_of_the_hunt
## (src/cards/legends.c:4252) just makes the token and mage-go
## approximates the ability as plain banding ("XXX" in
## cards/legends/creatures.go), which is what this file did until the lift.


func build() -> CardData:
	return CardData.new("Master of the Hunt", "{2}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human"]) \
		.activated(ActivatedAbility.new(
			"{2}{G}{G}", false, [MakeTokenEffect.new(_wolf_data())],
			"{2}{G}{G}: Create a 1/1 green Wolf creature token named Wolves of the Hunt.")) \
		.oracle("{2}{G}{G}: Create a 1/1 green Wolf creature token named Wolves of "
			+ "the Hunt. It has \"bands with other creatures named Wolves of the Hunt.\" "
			+ "(Any creatures named Wolves of the Hunt can attack in a band as long as "
			+ "at least one has \"bands with other creatures named Wolves of the Hunt.\" "
			+ "Bands are blocked as a group. If at least two creatures named Wolves of "
			+ "the Hunt you control, one of which has \"bands with other creatures named "
			+ "Wolves of the Hunt,\" are blocking or being blocked by the same creature, "
			+ "you divide that creature's combat damage, not its controller, among any "
			+ "of the creatures it's being blocked by or is blocking.)")


static func _wolf_data() -> CardData:
	return CardData.new("Wolves of the Hunt", "", Mtg.CardType.CREATURE) \
		.with_colors(Mtg.ManaColor.G) \
		.pt(1, 1) \
		.with_subtypes(["wolf"]) \
		.static_ability(StaticAbility.new(
			_grant_pack_banding,
			"Bands with other creatures named Wolves of the Hunt.")) \
		.oracle("Bands with other creatures named Wolves of the Hunt.")


## The token's OWN printed ability, so it grants itself (CR 702.22c's
## second form). Every member of the band must be a Wolf; the ability
## itself need only be on one of them.
static func _grant_pack_banding(_game: MtgGame, source: CardInstance) -> void:
	source.grant_bands_with("creatures named Wolves of the Hunt", _is_wolf)


## The quality: "other creatures named Wolves of the Hunt".
static func _is_wolf(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.data.card_name == "Wolves of the Hunt"


class MakeTokenEffect extends EffectBase:
	var token: CardData

	func _init(p_token: CardData) -> void:
		token = p_token

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.create_token(controller, token)

	func describe() -> String:
		return "creates a %s token" % token.card_name
