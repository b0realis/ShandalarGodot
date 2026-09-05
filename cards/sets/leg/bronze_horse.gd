extends CardScript
## Bronze Horse — {7} — Artifact Creature — Horse — 4/4 — (leg, rare)
## Oracle: Trample
##         As long as you control another creature, prevent all damage that
##         would be dealt to this creature by spells that target it.
##
## Implementation: a conditional static that hangs a source-filtered
## immunity on the Horse itself (CardInstance.cur_damage_immunity, the same
## list Argothian Pixies and Wall of Vapor use). The condition is re-read
## every recalculation, so the shield switches off the instant the Horse is
## alone.
##
## "By SPELLS THAT TARGET IT" is two tests, and the second is the
## interesting one: the source has to be a spell still on the stack, and the
## resolving object's own target list has to name this Horse
## (MtgGame.current_targets). A Fireball aimed at the Horse is stopped; an
## Earthquake, which targets nothing, is not, and neither is a Prodigal
## Sorcerer's ping, which is an ability rather than a spell.


func build() -> CardData:
	return CardData.new("Bronze Horse", "{7}", Mtg.CardType.ARTIFACT
			| Mtg.CardType.CREATURE) \
		.pt(4, 4) \
		.with_subtypes(["horse"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.static_ability(StaticAbility.new(
			_ward, "As long as you control another creature, prevent all damage that would be dealt to this creature by spells that target it.")) \
		.oracle("Trample\nAs long as you control another creature, prevent all "
			+ "damage that would be dealt to this creature by spells that target it.")


static func _ward(game: MtgGame, source: CardInstance) -> void:
	var others := 0
	for inst in game.players[source.controller_id].battlefield:
		if inst != source and inst.is_creature():
			others += 1
	if others == 0:
		return
	source.cur_damage_immunity.append({
		"desc": "spells that target it",
		"filter": _targeted_spell.bind(source.id),
	})


## Is [param damage_source] a SPELL that named [param horse_id] as one of
## its targets? Bound to the Horse's id by the static above, so the filter
## keeps MtgGame's plain (game, source) shape.
static func _targeted_spell(game: MtgGame, damage_source: CardInstance,
		horse_id: int) -> bool:
	if damage_source.zone != Mtg.Zone.STACK:
		return false   # an ability, a creature, a permanent's damage
	if not damage_source.data.is_type(Mtg.CardType.INSTANT) \
			and not damage_source.data.is_type(Mtg.CardType.SORCERY):
		return false
	for ref in game.current_targets():
		if not ref.is_player and not ref.is_damage and not ref.is_ability \
				and ref.instance_id == horse_id:
			return true
	return false
