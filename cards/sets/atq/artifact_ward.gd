extends CardScript
## Artifact Ward — {W} — Enchantment — Aura — (atq, common)
## Oracle: Enchant creature
##         Enchanted creature can't be blocked by artifact creatures.
##         Prevent all damage that would be dealt to enchanted creature by
##         artifact sources.
##         Enchanted creature can't be the target of abilities from
##         artifact sources.
##
## Implementation: all three clauses, each on the live-instance list that
## already exists for it — a block restriction, a source-filtered damage
## immunity (CardInstance.cur_damage_immunity) and a source-filtered
## TARGETING ban (CardInstance.cur_target_bans, read by TargetSpec).
##
## The ban is on ABILITIES from artifact sources, not on artifact spells:
## the ban filter tells the two apart the way the engine's "can't be the
## target of spells" clause does (TargetSpec.is_legal, Lurker) — a SPELL
## source is one being cast (still in hand while cast_spell validates it)
## or sitting on the stack; an ability's source is anywhere else, on the
## battlefield for every artifact in this pool. Rod of Ruin's ping is
## refused; an artifact spell (none in the 1997 pool targets a creature,
## but a synthetic one is pinned) is allowed.


func build() -> CardData:
	return CardData.new("Artifact Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_ward,
			"Enchanted creature can't be blocked by artifact creatures, is immune to damage from artifact sources, and can't be targeted by artifact sources.")) \
		.oracle("Enchant creature\nEnchanted creature can't be blocked by artifact creatures.\nPrevent all damage that would be dealt to enchanted creature by artifact sources.\nEnchanted creature can't be the target of abilities from artifact sources.")


static func _not_an_artifact(blocker: CardInstance) -> bool:
	return not blocker.is_type(Mtg.CardType.ARTIFACT)


static func _from_an_artifact(_game: MtgGame, damage_source: CardInstance) -> bool:
	return damage_source != null and damage_source.is_type(Mtg.CardType.ARTIFACT)


## TargetSpec hands the ban (game, targeting source, spec); an artifact
## source's ABILITY may not aim at the enchanted creature. A source in
## hand (being cast) or on the stack is a spell, which the ward lets by.
static func _targeted_by_an_artifact(_game: MtgGame, targeting: CardInstance,
		_spec: TargetSpec) -> bool:
	if targeting == null or not targeting.is_type(Mtg.CardType.ARTIFACT):
		return false
	return targeting.zone != Mtg.Zone.STACK and targeting.zone != Mtg.Zone.HAND


static func _ward(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	host.cur_block_restrictions.append({
		"desc": "creatures that aren't artifacts", "filter": _not_an_artifact,
	})
	host.cur_damage_immunity.append({
		"desc": "artifact sources", "filter": _from_an_artifact,
	})
	host.cur_target_bans.append({
		"desc": "artifact sources", "filter": _targeted_by_an_artifact,
	})
