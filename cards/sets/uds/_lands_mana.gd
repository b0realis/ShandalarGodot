extends RefCounted
## Urza's Destiny (_lands_mana, Pack 10). Lands and mana abilities, in Urza's
## Saga's shapes (cards/sets/usg/_lands_mana.gd).
##
## - Heart Warden: an Elf's {T}: Add {G}; "{2}, Sacrifice this creature:
##   Draw a card" sacrifices as the cost (CR 602.2).
## - Rofellos, Llanowar Emissary: {G} for each Forest its activator controls
##   (live land subtypes, CR 109.5); legendary (the 1997 legend rule).
## - Thran Dynamo: {C}{C}{C}.
## - Yavimaya Hollow: legendary; {C}, or {G},{T} to regenerate target
##   creature.
##
## tests/cards/test_pack_10_B9_lands_mana.gd pins each card.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Heart Warden":
			c.mana(ManaAbility.new(Mtg.ManaColor.G))
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice this creature: Draw a card.").with_sacrifice_cost())
		"Rofellos, Llanowar Emissary":
			c.mana(ManaAbility.new(Mtg.ManaColor.G).with_dynamic_amount(_forests, true))
		"Thran Dynamo":
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 3))
		"Yavimaya Hollow":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{G}", true, [RegenerateEffect.new().target_creature()],
				"{G}, {T}: Regenerate target creature."))
		_: return false
	return true


## "For each Forest you control" — [param pid] is the activator.
static func _forests(g: MtgGame, _s: CardInstance, pid: int) -> int:
	if pid < 0 or pid >= g.players.size(): return 0
	var n := 0
	for inst in g.players[pid].battlefield:
		if not inst.phased_out and inst.is_land() and inst.has_subtype("forest"): n += 1
	return n
