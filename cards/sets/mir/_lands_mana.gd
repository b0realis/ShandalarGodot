extends RefCounted
## Mirage (_lands_mana, Pack 8). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## Every mana source here is declared in a shape the one mana planner
## (engine/mana_planner.gd — the AI's plans and the human auto-cast) can
## read without running a callback: a fixed output, an "{N}, {T}: Add …"
## conversion opted in with [method ManaAbility.with_plannable_conversion]
## (School of the Unseen's shape), "any colour" as one ability per colour
## (Black Lotus, City of Brass), and a self-sacrifice as
## [method ManaAbility.with_sacrifice], which the planner sorts last.
## The fetch lands are not mana sources at all: "{T}, Sacrifice this land:
## Search …" is an activated ability that uses the stack (CR 605.1a — it
## adds no mana).
const F := preload("res://cards/sets/fem/_rules.gd")
const OC := preload("res://engine/additional_object_costs.gd")

const DIAMONDS := {
	"Charcoal Diamond": Mtg.ManaColor.B, "Fire Diamond": Mtg.ManaColor.R,
	"Marble Diamond": Mtg.ManaColor.W, "Moss Diamond": Mtg.ManaColor.G,
	"Sky Diamond": Mtg.ManaColor.U,
}

## fetch land -> [land type, land type, what it searches for]
const FETCHES := {
	"Bad River": ["island", "swamp", "an Island or Swamp card"],
	"Flood Plain": ["plains", "island", "a Plains or Island card"],
	"Grasslands": ["forest", "plains", "a Forest or Plains card"],
	"Mountain Valley": ["mountain", "forest", "a Mountain or Forest card"],
	"Rocky Tar Pit": ["swamp", "mountain", "a Swamp or Mountain card"],
}

static func configure(c: CardData) -> bool:
	var n := c.card_name
	if DIAMONDS.has(n):
		c.with_enters_tapped()
		c.mana(ManaAbility.new(DIAMONDS[n]))
		return true
	if FETCHES.has(n):
		var row: Array = FETCHES[n]
		c.with_enters_tapped()
		# "Island or Swamp CARD": land types, so a nonbasic dual with the
		# type qualifies (CR 305.6-8); it enters untapped, as printed.
		var search := SearchLibraryEffect.new(row[2], _either_type.bind(row[0], row[1])).to_battlefield()
		search.with_ai_role(&"land_search")
		c.activated(ActivatedAbility.new("", true, [search],
			"{T}, Sacrifice this land: Search your library for %s, put it onto the battlefield, then shuffle." % row[2]).with_sacrifice_cost())
		return true
	match n:
		"Sea Scryer":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.mana(ManaAbility.new(Mtg.ManaColor.U).with_mana_cost("{1}").with_plannable_conversion())
		"Quirion Elves":
			# "As this creature enters, choose a color" is a replacement
			# (CR 614.1c), so the choice exists before the creature can be
			# tapped; the second ability reads it from the card's memory.
			c.as_it_enters(_choose_color)
			c.mana(ManaAbility.new(Mtg.ManaColor.G))
			c.mana(ManaAbility.new(Mtg.ManaColor.G).with_dynamic_color(_chosen_color).with_dynamic_amount(_chosen_amount))
		"Mana Prism":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color).with_mana_cost("{1}").with_plannable_conversion())
		"Crystal Vein":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 2).with_sacrifice())
		"Wall of Roots":
			# No {T}: usable while summoning sick and while tapped (CR 302.6).
			# The -0/-1 counter is a COST (CR 118.3) put as the ability is
			# activated, so the mana is made even if it kills the Wall; once
			# per turn, counted per object (CR 400.7).
			c.mana(ManaAbility.new(Mtg.ManaColor.G).without_tap().with_put_counter_cost("-0/-1").per_turn(1))
		"Cadaverous Bloom":
			# Two mana abilities, one per pair; the exiled card is the
			# payer's choice. An object cost: never auto-planned.
			for color in [Mtg.ManaColor.B, Mtg.ManaColor.G]:
				c.mana(ManaAbility.new(color, 2).without_tap().with_object_cost(OC.exiling(Mtg.Zone.HAND, "a card")))
		"Lion's Eye Diamond":
			# "Discard your hand, Sacrifice this artifact: Add three mana of
			# any one color. Activate only as an instant." One row per colour
			# (the Black Lotus shape); only while its controller holds
			# priority outside any resolution or payment (its ruling), and
			# never auto-planned.
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color, 3).without_tap().with_sacrifice() \
					.with_object_cost(OC.discard_hand()).as_instant())
		_: return false
	return true

static func _either_type(i: CardInstance, first: String, second: String) -> bool:
	return i.has_subtype(first) or i.has_subtype(second)

## The colour is the controller's to name. The hint is the colour the seat's
## OWN hand asks for most beyond green (the Elves' first ability already
## makes green) — its own hand only, never anything hidden (CONTRIBUTING.md
## rule 8).
static func _choose_color(g: MtgGame, s: CardInstance, pid: int) -> void:
	var want := {}
	for card in g.players[pid].hand:
		for color in card.data.cost.colored:
			want[int(color)] = int(want.get(int(color), 0)) + int(card.data.cost.colored[color])
	var best: int = Mtg.ManaColor.G
	var most := 0
	for color in Mtg.WUBRG:
		if color != Mtg.ManaColor.G and int(want.get(color, 0)) > most:
			best = color
			most = int(want[color])
	var picked := g.agents[pid].choose_color(g, pid, "%s: choose a color" % s.data.card_name, best)
	g._rec(s, &"memory")
	s.memory["chosen_color"] = picked if Mtg.WUBRG.has(picked) else best

static func _chosen_color(_g: MtgGame, s: CardInstance) -> int:
	return int(s.memory.get("chosen_color", Mtg.ManaColor.G))

## No colour was ever chosen (the card never entered the usual way): the
## ability has no colour to make, so it makes nothing.
static func _chosen_amount(_g: MtgGame, s: CardInstance) -> int:
	return 1 if s.memory.has("chosen_color") else 0
