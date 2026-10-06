extends RefCounted
## Stronghold (_lands_mana, Pack 9). Nonbasic lands and mana abilities, including sacrifice and tapped-entry lands.
##
## Mana sources are declared in shapes the one mana planner
## (engine/mana_planner.gd) reads without callbacks: "one mana of any color"
## as one ability per colour (Black Lotus, City of Brass, Lotus Vale).
## Mox Diamond's "if this would enter, you may discard a land card instead"
## is an ENTRY PAYMENT (CardData.entry_payment, Lotus Vale's shape in
## cards/sets/wth/_lands_mana.gd): a replacement of the arrival (CR 614.1c)
## asked however it would enter — cast, or put onto the battlefield by an
## effect. No discard puts it into its owner's graveyard; it never entered,
## so nothing sees it enter or die. tests/cards/test_pack_9_B9_lands_mana.gd.

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Mox Diamond":
			c.entry_payment = _discard_a_land
			for color in Mtg.WUBRG:
				c.mana(ManaAbility.new(color))
		"Skyshroud Troopers":
			# A creature's {T} mana ability waits out summoning sickness (CR 302.6).
			c.mana(ManaAbility.new(Mtg.ManaColor.G))
		"Volrath's Stronghold":
			# The scaffold prints the legendary supertype (the legend rule —
			# 1997's "newest is buried" under `fifth` — is the engine's).
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
			c.activated(ActivatedAbility.new("{1}{B}", true, [CreatureCardToTop.new()],
				"{1}{B}, {T}: Put target creature card from your graveyard on top of your library."))
		_: return false
	return true


## "You may discard a land card instead." Optional — declining (or holding
## no land card) puts the Mox into its owner's graveyard. The offered order
## (a heuristic seat takes the first): basic lands before nonbasic ones.
static func _discard_a_land(g: MtgGame, s: CardInstance, pid: int) -> bool:
	var lands: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card != s and card.data.is_land():
			lands.append(card)
	if lands.is_empty():
		return false
	lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return (a.data.supertypes & Mtg.Supertype.BASIC) > (b.data.supertypes & Mtg.Supertype.BASIC))
	var pick := g.agents[pid].choose_card(g, pid, lands,
		"Discard a land card for %s, or put it into its owner's graveyard" % s.data.card_name, true, false, true)
	if pick == null or not lands.has(pick):
		return false
	g.discard_cards(pid, [pick])
	return true


## "Put target creature card from your graveyard on top of your library."
## A ReturnFromGraveyardEffect (its default target is a creature card in
## your graveyard), so the fair AI reads the recursion as one.
class CreatureCardToTop extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		ai_helpful = true

	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var card := g.find_instance(t.instance_id)
		if card != null and card.zone == Mtg.Zone.GRAVEYARD:
			g.return_from_graveyard_to_library_top(card)

	func describe() -> String:
		return "put target creature card from your graveyard on top of your library"
