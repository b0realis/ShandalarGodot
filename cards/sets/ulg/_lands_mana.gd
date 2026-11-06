extends RefCounted
## Urza's Legacy (_lands_mana, Pack 10). Lands and mana abilities: the five
## creature lands.
##
## Each enters tapped, taps for its colour, and for {1} and its colour
## becomes a creature until end of turn that is still a land (Mishra's
## Factory's AnimateSelfEffect, so the computer reads it as the Factory):
## the animation adds the creature type and subtype and sets the base P/T
## (layers 4 and 7b), the colour is SET (layer 5 — "a 2/1 blue Faerie"), the
## keyword is a layer-6 grant, all until end of turn and all at the
## activation's own timestamps (CR 613.7). Spawning Pool's Skeleton is also
## granted "{B}: Regenerate this creature" until end of turn
## (ContinuousEffects.add_granted_activated_ability, the Ice Age shape).
## Only the very land whose ability it is animates (CR 400.7). A land played
## this turn can animate but not attack (summoning sickness, CR 302.6).
##
## tests/cards/test_pack_10_B9_manlands.gd pins each card.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Faerie Conclave":
			_creature_land(c, Mtg.ManaColor.U, "{1}{U}", Manland.new(2, 1, "faerie", Mtg.ManaColor.U, [Mtg.Keyword.FLYING]),
				"{1}{U}: This land becomes a 2/1 blue Faerie creature with flying until end of turn. It's still a land.")
		"Forbidding Watchtower":
			_creature_land(c, Mtg.ManaColor.W, "{1}{W}", Manland.new(1, 5, "soldier", Mtg.ManaColor.W, []),
				"{1}{W}: This land becomes a 1/5 white Soldier creature until end of turn. It's still a land.")
		"Ghitu Encampment":
			_creature_land(c, Mtg.ManaColor.R, "{1}{R}", Manland.new(2, 1, "warrior", Mtg.ManaColor.R, [Mtg.Keyword.FIRST_STRIKE]),
				"{1}{R}: This land becomes a 2/1 red Warrior creature with first strike until end of turn. It's still a land. (It deals combat damage before creatures without first strike.)")
		"Spawning Pool":
			var skeleton := Manland.new(1, 1, "skeleton", Mtg.ManaColor.B, [])
			skeleton.granted = ActivatedAbility.new("{B}", false, [RegenerateEffect.new()],
				"{B}: Regenerate this creature.")
			_creature_land(c, Mtg.ManaColor.B, "{1}{B}", skeleton,
				"{1}{B}: This land becomes a 1/1 black Skeleton creature with \"{B}: Regenerate this creature\" until end of turn. It's still a land. (If it regenerates, the next time it would be destroyed this turn, instead tap it, remove it from combat, and heal all damage on it.)")
		"Treetop Village":
			_creature_land(c, Mtg.ManaColor.G, "{1}{G}", Manland.new(3, 3, "ape", Mtg.ManaColor.G, [Mtg.Keyword.TRAMPLE]),
				"{1}{G}: This land becomes a 3/3 green Ape creature with trample until end of turn. It's still a land. (It can deal excess combat damage to the player or planeswalker it's attacking.)")
		_: return false
	return true


static func _creature_land(c: CardData, color: int, cost: String, animation: Manland, text: String) -> void:
	c.with_enters_tapped()
	c.mana(ManaAbility.new(color))
	c.activated(ActivatedAbility.new(cost, false, [animation], text))


## "This land becomes a P/T <colour> <Subtype> creature [with <keyword>]
## until end of turn. It's still a land."
class Manland extends AnimateSelfEffect:
	var color: int
	var keywords: Array[int] = []
	## An ability the creature has for the turn (Spawning Pool), or null.
	var granted: ActivatedAbility = null

	func _init(power: int, toughness: int, subtype: String, p_color: int, p_keywords: Array) -> void:
		super(Mtg.CardType.CREATURE, power, toughness, [subtype])
		color = p_color
		for k in p_keywords: keywords.append(int(k))

	func resolve(g: MtgGame, source: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if not F._same_activation_source(g, source):
			return   # gone, phased out, or a new object (CR 400.7, 702.26e)
		g.continuous.add_until_eot_animation(source.id, add_types, set_power, set_toughness, add_subtypes)
		g.continuous.add_until_eot_color(source.id, color)
		if not keywords.is_empty():
			g.continuous.add_until_eot_keywords(source.id, keywords)
		if granted != null:
			g.continuous.add_granted_activated_ability(source.id, granted,
				ContinuousEffects.Duration.END_OF_TURN)
		g.log_line("%s becomes a %d/%d creature until end of turn" % [
			source.data.card_name, set_power, set_toughness])
		g.recalculate()
