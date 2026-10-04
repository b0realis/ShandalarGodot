extends RefCounted
## Weatherlight (_lands_mana, Pack 8). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## Mana sources are declared in shapes the one mana planner
## (engine/mana_planner.gd) reads without callbacks: "any colour" as one
## ability per colour (Black Lotus, City of Brass), and Gemstone Mine's
## counter cost opted in with [member ManaAbility.planner_counter_cost] (the
## storage shape of cards/sets/ice/_storage.gd — one tap spends one row, so a
## plan can never count the same counter twice).
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Mind Stone":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{1}", true, [DrawEffect.new(1)],
				"{1}, {T}, Sacrifice this artifact: Draw a card.").with_sacrifice_cost())
		"Gemstone Mine":
			c.with_enters_counters("mining", 3)
			for color in Mtg.WUBRG:
				var mine := ManaAbility.new(color).with_counter_cost("mining").with_side_effect(_exhausted)
				mine.planner_counter_cost = true
				c.mana(mine)
		"Lotus Vale":
			c.entry_payment = _two_untapped_lands
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color, 3))
		"Scorched Ruins":
			c.entry_payment = _two_untapped_lands
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 4))
		"Winding Canyons":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{2}", true, [F.Action.new(_canyons,
				"you may cast creature spells this turn as though they had flash", null, true)],
				"{2}, {T}: You may cast creature spells this turn as though they had flash."))
		_: return false
	return true

## A permission of the activating player's seat, emptied at cleanup
## (CR 702.8, MtgGame.grant_flash).
static func _canyons(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.grant_flash(pid, _creature_spell, "creature spells this turn")

static func _creature_spell(_g: MtgGame, i: CardInstance) -> bool:
	return i.is_creature()

## "If there are no mining counters on this land, sacrifice it." Part of the
## mana ability's own effect, so it happens as the ability resolves (CR
## 605.3b), after the mana is added — never through the stack.
static func _exhausted(g: MtgGame, s: CardInstance, _pid: int) -> void:
	if s.zone == Mtg.Zone.BATTLEFIELD and int(s.counters.get("mining", 0)) <= 0:
		g.sacrifice_permanent(s)

## "If this land would enter, sacrifice two untapped lands instead. If you
## do, put this land onto the battlefield. If you don't, put it into its
## owner's graveyard." A replacement of the arrival (CR 614.1c,
## CardData.entry_payment): both lands are chosen before either is
## sacrificed, so a refusal half-way leaves the board as it was, and the
## controller may decline outright. A PLAYED land's picks are put to a human
## seat with the land drop held open (MtgGame._hold_entry_payment).
static func _two_untapped_lands(g: MtgGame, s: CardInstance, pid: int) -> bool:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i != s and i.is_land() and not i.tapped:
			choices.append(i)
	if choices.size() < 2:
		return false
	var picked: Array[CardInstance] = []
	for n in 2:
		var offered: Array[CardInstance] = []
		for i in choices:
			if not picked.has(i):
				offered.append(i)
		var pick := g.agents[pid].choose_card(g, pid, offered,
			"Sacrifice an untapped land (%d of 2) for %s, or put it into its owner's graveyard" % [n + 1, s.data.card_name], true)
		if pick == null or not offered.has(pick):
			return false
		picked.append(pick)
	g.begin_simultaneous()
	for i in picked:
		g.sacrifice_permanent(i)
	g.end_simultaneous()
	return true
