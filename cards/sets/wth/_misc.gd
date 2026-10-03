extends RefCounted
## Weatherlight (_misc, Pack 8). Everything else: world enchantments, global effects and one-off rules.
##
## The global enchantments of batch B5: anthems of a keyword (layer 6 —
## StaticAbility.changing_abilities), a targeting ban, and activated
## abilities built from the typed effects the fair AI reads
## (engine/ai/effect_intent.gd) wherever one fits.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Serra's Blessing":
			c.static_ability(StaticAbility.new(_grant_yours.bind(Mtg.Keyword.VIGILANCE),
				"Creatures you control have vigilance.").changing_abilities())
		"Fervor":
			c.static_ability(StaticAbility.new(_grant_yours.bind(Mtg.Keyword.HASTE),
				"Creatures you control have haste.").changing_abilities())
		"Dense Foliage":
			c.static_ability(StaticAbility.new(_foliage, "Creatures can't be the targets of spells."))
		"Infernal Tribute":
			c.activated(ActivatedAbility.new("{2}", false, [DrawEffect.new(1)],
				"{2}, Sacrifice a nontoken permanent: Draw a card.")
				.with_sacrifice_of("nontoken permanent", _nontoken).may_sacrifice_itself())
		"Strands of Night":
			c.activated(ActivatedAbility.new("{B}{B}", false, [ReturnFromGraveyardEffect.new().to_battlefield()],
				"{B}{B}, Pay 2 life, Sacrifice a Swamp: Return target creature card from your graveyard to the battlefield.")
				.with_life_cost(2).with_sacrifice_of("Swamp", _swamp))
		"Call of the Wild":
			c.activated(ActivatedAbility.new("{2}{G}{G}", false,
				[F.Action.new(_call_of_the_wild, "reveal the top card of your library; a creature card enters the battlefield, anything else goes to your graveyard", null, true)],
				"{2}{G}{G}: Reveal the top card of your library. If it's a creature card, put it onto the battlefield. Otherwise, put it into your graveyard."))
		"Downdraft":
			c.activated(ActivatedAbility.new("{G}", false, [LoseAbilityEffect.new([Mtg.Keyword.FLYING], "flying")],
				"{G}: Target creature loses flying until end of turn."))
			c.activated(ActivatedAbility.new("", false, [DamageAllEffect.new(2, "each creature with flying", _flying)],
				"Sacrifice this enchantment: It deals 2 damage to each creature with flying.").with_sacrifice_cost())
		"Tranquil Grove":
			c.activated(ActivatedAbility.new("{1}{G}{G}", false, [OtherEnchantments.new()],
				"{1}{G}{G}: Destroy all other enchantments."))
		"Desperate Gambit":
			c.spell(F.Action.new(_gambit,
				"choose a source you control and flip a coin: if you win, the next time it would deal damage this turn it deals double; if you lose, that damage is prevented"))
		_: return false
	return true


static func _nontoken(i: CardInstance) -> bool:
	return not i.is_token

static func _swamp(i: CardInstance) -> bool:
	return i.has_subtype("swamp")

static func _flying(i: CardInstance) -> bool:
	return i.has_keyword(Mtg.Keyword.FLYING)

## "Creatures you control have <keyword>" (CR 613 layer 6).
static func _grant_yours(g: MtgGame, s: CardInstance, keyword: int) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature() and not i.cur_keywords.has(keyword):
			i.cur_keywords.append(keyword)

## Spells only — abilities still target (the engine's Lurker flag reads
## the targeting source's zone: a spell is in a hand or on the stack).
static func _foliage(g: MtgGame, _s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_cant_be_spell_target = true

## The revealed card is public; a creature card enters under the
## activator's control, anything else is put into their graveyard.
static func _call_of_the_wild(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var library := g.players[pid].library
	if library.is_empty(): return
	var top: CardInstance = library.back()
	g.reveal_information(-1, "Call of the Wild reveals", [top.data.card_name])
	g.log_line("Call of the Wild: %s reveals %s" % [g.players[pid].player_name, top.data.card_name])
	if top.data.is_creature():
		g.put_library_card_onto_battlefield(top, pid)
	else:
		g.mill(pid, 1)


## Desperate Gambit (E5's damage-effect registry): the source is chosen on
## resolution among the sources the caster controls (permanents and their
## spells on the stack), ranked by the threat each poses to the opponent;
## the flip is the game's (MtgGame.flip_coin, game.rng). Both outcomes are
## one-shot entries used up by the source's next damage EVENT this turn,
## whatever it hits (CR 615.8, 614 — a "next time" effect).
static func _gambit(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var foe := g.opponent_of(pid)
	var threatened: Array = [TargetRef.player(foe)]
	for i in g.players[foe].battlefield:
		if i.is_creature(): threatened.append(TargetRef.card(i))
	var source := g.choose_damage_source(pid, "Desperate Gambit: Select a source you control.",
		_controlled_by.bind(pid), threatened)
	if source == null: return
	if g.flip_coin(pid):
		g.modify_next_damage(pid, "Desperate Gambit", source, 2)
	else:
		g.add_damage_effect({"kind": &"prevent", "one_shot": true, "source": source, "controller": pid,
			"card": "Desperate Gambit", "desc": "Desperate Gambit (%s)" % source.data.card_name})

static func _controlled_by(i: CardInstance, pid: int) -> bool:
	return i.controller_id == pid


## "Destroy all OTHER enchantments" — the typed sweeper, minus its source.
class OtherEnchantments extends DestroyAllEffect:
	func _init() -> void:
		super("all other enchantments", _is_enchantment)

	static func _is_enchantment(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ENCHANTMENT)

	func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
			_x_value: int = 0) -> void:
		var victims: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if inst != source and inst.is_type(Mtg.CardType.ENCHANTMENT):
				victims.append(inst)
		game.begin_simultaneous()
		for inst in victims:
			game.destroy(inst, can_regenerate)
		game.end_simultaneous()
