extends CardScript
## Camel — {W} — Creature — Camel — 0/1 — (arn, common)
## Oracle: Banding
##         As long as this creature is attacking, prevent all damage
##         Deserts would deal to this creature and to creatures banded with
##         this creature.
##
## Implementation: banding plus a source-filtered damage immunity against
## Deserts — the same cur_damage_immunity list Desert Nomads uses, applied
## to the Camel and to every other member of its attacking band.


func build() -> CardData:
	return CardData.new("Camel", "{W}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["camel"]) \
		.with_keywords([Mtg.Keyword.BANDING]) \
		.static_ability(StaticAbility.new(_shelter,
			"As long as this creature is attacking, prevent all damage Deserts would deal to it and to creatures banded with it.")) \
		.oracle("Banding (Any creatures with banding, and up to one without, can attack in a band. Bands are blocked as a group. If any creatures with banding you control are blocking or being blocked by a creature, you divide that creature's combat damage, not its controller, among any of the creatures it's being blocked by or is blocking.)\nAs long as this creature is attacking, prevent all damage Deserts would deal to this creature and to creatures banded with this creature.")


static func _is_a_desert(_game: MtgGame, damage_source: CardInstance) -> bool:
	return damage_source != null and damage_source.has_subtype("desert")


static func _shelter(game: MtgGame, source: CardInstance) -> void:
	if not game.combat.attackers.has(source.id):
		return
	for member_id in game.combat.band_of(source.id):
		var member := game.find_instance(member_id)
		if member == null or member.zone != Mtg.Zone.BATTLEFIELD:
			continue
		member.cur_damage_immunity.append({
			"desc": "Deserts", "filter": _is_a_desert,
		})
