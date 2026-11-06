extends RefCounted
## Urza's Saga (_opal, Pack 10). Enchantments that become creatures — the
## Opal, Veiled, Hidden and Lurking enchantments — and Soul Sculptor; the
## shared helpers cards/sets/ulg/_opal.gd and cards/sets/uds/_opal.gd
## preload (Opalescence lives in the Destiny one).
##
## - "IT BECOMES A P/T <TYPE> CREATURE" REPLACES THE CARD TYPE (CR 205.1a;
##   Pack 10 E3, [method ContinuousEffects.add_type_change]): the permanent
##   is a creature and no longer an enchantment — an Aura that enchants
##   enchantments falls off, Disenchant cannot target it, Opalescence lets it
##   go — for the rest of the game (no duration is stated, CR 611.2a) or
##   until it leaves (CR 400.7). The size is a base P/T set at the same
##   moment (layer 7b: a Humility older than it leaves the printed size, a
##   newer one makes it 1/1, CR 613.7); "with flying" and kin are
##   durationless grants on the layer-6 clock
##   ([method MtgGame.grant_keyword_permanently]).
## - "IF THIS PERMANENT IS AN ENCHANTMENT" is an intervening if (CR 603.4):
##   the trigger condition, asked again as it resolves — a second trigger
##   already on the stack does nothing. A trigger whose permanent left and
##   came back does nothing (the same object, CR 400.7). Under Opalescence a
##   dormant one is an enchantment creature — still an enchantment, so it
##   triggers, becomes its creature and stops being an enchantment.
## - "When a player has no cards in hand", "when you have 10 or less life"
##   and kin are STATE triggers (CR 603.8): once, and not again while that
##   one waits on the stack.
## - Veiled Apparition's granted upkeep trigger and Veiled Serpent's granted
##   Island clause are FLOATING statics bound to the permanent, stamped as
##   they are granted: a Humility older than the grant leaves them, a newer
##   one removes them (CR 613.7).
## - Soul Sculptor: the type change and a floating "loses all abilities"
##   bound to the target, both ending as ANY player casts a creature spell
##   ([method ContinuousEffects.until_spell_cast]: as the spell becomes
##   cast, CR 601.2i — not when it resolves).
## tests/cards/test_pack_10_B12_*.gd pin each card.

const F := preload("res://cards/sets/fem/_rules.gd")
const D := ContinuousEffects.Duration
const CREATURE := Mtg.CardType.CREATURE
const ENCHANTMENT := Mtg.CardType.ENCHANTMENT


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Opal Acrolith":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(CREATURE),
				"Whenever an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/4 Soldier creature.",
				2, 4, ["soldier"])
			c.activated(ActivatedAbility.new("{0}", false,
				[F.Action.new(_to_enchantment, "this permanent becomes an enchantment")],
				"{0}: This permanent becomes an enchantment."))
		"Opal Archangel":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(CREATURE),
				"When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 5/5 Angel creature with flying and vigilance.",
				5, 5, ["angel"], [Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
		"Opal Caryatid":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(CREATURE),
				"When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/2 Soldier creature.",
				2, 2, ["soldier"])
		"Opal Gargoyle":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(CREATURE),
				"When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 2/2 Gargoyle creature with flying.",
				2, 2, ["gargoyle"], [Mtg.Keyword.FLYING])
		"Opal Titan":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(CREATURE),
				"When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 4/4 Giant creature with protection from each of that spell's colors.",
				4, 4, ["giant"], [], _titan_protection, _spell_context)
		"Soul Sculptor":
			c.activated(ActivatedAbility.new("{1}{W}", true,
				[F.Action.new(_sculpt,
					"target creature becomes an enchantment and loses all abilities until a player casts a creature spell",
					TargetSpec.creature())],
				"{1}{W}, {T}: Target creature becomes an enchantment and loses all abilities until a player casts a creature spell."))
		"Veil of Birds":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(0),
				"When an opponent casts a spell, if this permanent is an enchantment, it becomes a 1/1 Bird creature with flying.",
				1, 1, ["bird"], [Mtg.Keyword.FLYING])
		"Veiled Apparition":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(0),
				"When an opponent casts a spell, if this permanent is an enchantment, it becomes a 3/3 Illusion creature with flying and \"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.\"",
				3, 3, ["illusion"], [Mtg.Keyword.FLYING], _apparition_upkeep_grant)
		"Veiled Crocodile":
			becomes(c, Mtg.EventType.STATE_CHECK, _a_hand_is_empty,
				"When a player has no cards in hand, if this permanent is an enchantment, it becomes a 4/4 Crocodile creature.",
				4, 4, ["crocodile"])
		"Veiled Sentry":
			var sentry := TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _sentry,
				"When an opponent casts a spell, if this permanent is an enchantment, it becomes an Illusion creature with power and toughness each equal to that spell's mana value.",
				_while_enchantment.bind(opponent_casts.bind(0)))
			c.triggered(sentry.capturing(_spell_context))
		"Veiled Serpent":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(0),
				"When an opponent casts a spell, if this permanent is an enchantment, it becomes a 4/4 Serpent creature with \"This creature can't attack unless defending player controls an Island.\"",
				4, 4, ["serpent"], [], _serpent_island_grant)
			c.with_cycling("{2}")
		"Lurking Evil":
			c.activated(ActivatedAbility.new("", false,
				[F.Action.new(_lurking_evil, "this enchantment becomes a 4/4 Phyrexian Horror creature with flying")],
				"Pay half your life, rounded up: This enchantment becomes a 4/4 Phyrexian Horror creature with flying.") \
				.with_half_life_cost())
		"Hidden Ancients":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(ENCHANTMENT),
				"When an opponent casts an enchantment spell, if this permanent is an enchantment, it becomes a 5/5 Treefolk creature.",
				5, 5, ["treefolk"])
		"Hidden Guerrillas":
			becomes(c, Mtg.EventType.SPELL_CAST, opponent_casts.bind(Mtg.CardType.ARTIFACT),
				"When an opponent casts an artifact spell, if this permanent is an enchantment, it becomes a 5/3 Soldier creature with trample.",
				5, 3, ["soldier"], [Mtg.Keyword.TRAMPLE])
		"Hidden Herd":
			becomes(c, Mtg.EventType.LAND_PLAYED, _opponent_plays_nonbasic,
				"When an opponent plays a nonbasic land, if this permanent is an enchantment, it becomes a 3/3 Beast creature.",
				3, 3, ["beast"])
		"Hidden Predators":
			becomes(c, Mtg.EventType.STATE_CHECK, _opponent_has_power_four,
				"When an opponent controls a creature with power 4 or greater, if this permanent is an enchantment, it becomes a 4/4 Beast creature.",
				4, 4, ["beast"])
		"Hidden Spider":
			becomes(c, Mtg.EventType.SPELL_CAST, _opponent_casts_flyer,
				"When an opponent casts a creature spell with flying, if this permanent is an enchantment, it becomes a 3/5 Spider creature with reach.",
				3, 5, ["spider"], [Mtg.Keyword.REACH])
		"Hidden Stag":
			becomes(c, Mtg.EventType.LAND_PLAYED, _opponent_plays_land,
				"Whenever an opponent plays a land, if this permanent is an enchantment, it becomes a 3/2 Elk Beast creature.",
				3, 2, ["elk", "beast"])
			c.triggered(TriggeredAbility.new(Mtg.EventType.LAND_PLAYED, _stag_settles,
				"Whenever you play a land, if this permanent is a creature, it becomes an enchantment.",
				_you_play_a_land_as_a_creature))
		_: return false
	return true


# ============================================================ the family

## "When <event>, if this permanent is an enchantment, it becomes a P/T
## <subtypes> creature [with <keywords>]." — [param when] is the trigger
## event's own test `func(g, s, e) -> bool`; [param after] runs on [param s]
## once it has become the creature (a granted ability, a protection);
## [param capture] replaces the default trigger context (the spell's colours
## or mana value as it was cast).
static func becomes(c: CardData, event_type: int, when: Callable, text: String,
		power: int, toughness: int, subtypes: Array, keywords: Array = [],
		after: Callable = Callable(), capture: Callable = Callable()) -> TriggeredAbility:
	var trigger := TriggeredAbility.new(event_type,
		_become.bind(power, toughness, subtypes, keywords, after), text,
		_while_enchantment.bind(when))
	trigger.capturing(capture if capture.is_valid() else F._source_context)
	c.triggered(trigger)
	return trigger


## The intervening "if this permanent is an enchantment" (CR 603.4) in front
## of the event's own test.
static func _while_enchantment(g: MtgGame, s: CardInstance, e: GameEvent, when: Callable) -> bool:
	return s.is_type(ENCHANTMENT) and bool(when.call(g, s, e))


static func _become(g: MtgGame, s: CardInstance, e: GameEvent, power: int, toughness: int,
		subtypes: Array, keywords: Array, after: Callable) -> void:
	# The same object (CR 400.7), and still an enchantment (CR 603.4).
	if not F._same_trigger_source(g, s) or not s.is_type(ENCHANTMENT):
		return
	make_creature(g, s, power, toughness, subtypes, keywords)
	if after.is_valid():
		after.call(g, s, e)


## "<s> becomes a P/T <subtypes> creature [with <keywords>]" — the card type
## REPLACED (CR 205.1a), indefinitely; the size a layer-7b set at the same
## moment; the keywords durationless grants. Public: Lurking Evil's ability
## and every module of the family call it.
static func make_creature(g: MtgGame, s: CardInstance, power: int, toughness: int,
		subtypes: Array, keywords: Array = []) -> void:
	g.continuous.add_type_change(s.id, {"set_types": CREATURE, "set_subtypes": subtypes})
	g.continuous.add_until_eot_base_pt(s.id, power, toughness, false, D.INDEFINITE)
	var words := PackedStringArray()
	for subtype in subtypes:
		words.append(String(subtype).capitalize())
	g.log_line("%s becomes a %d/%d %s creature" % [s.data.card_name, power, toughness,
		" ".join(words)], s)
	for keyword in keywords:
		g.grant_keyword_permanently(s, int(keyword))
	g.recalculate()


## "<s> becomes an enchantment" — the card type replaced the other way: no
## longer a creature, its creature types gone (CR 205.1a). Opal Acrolith's
## {0}, Hidden Stag's second trigger.
static func make_enchantment(g: MtgGame, s: CardInstance) -> void:
	g.continuous.add_type_change(s.id, {"set_types": ENCHANTMENT})
	g.log_line("%s becomes an enchantment" % s.data.card_name, s)
	g.recalculate()


# ------------------------------------------------------- trigger events --

## "When an opponent casts a [<kind>] spell" — [param types] 0 = any spell;
## the kind read LIVE off the stack.
static func opponent_casts(_g: MtgGame, s: CardInstance, e: GameEvent, types: int) -> bool:
	var spell: CardInstance = e.data.get("instance", null)
	if spell == null:
		return false
	var caster := int(e.data.get("controller", -1))
	return caster >= 0 and caster != s.controller_id and (types == 0 or spell.is_type(types))


## "When an opponent casts a creature spell with flying" (Hidden Spider).
static func _opponent_casts_flyer(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if not opponent_casts(g, s, e, CREATURE):
		return false
	return (e.data["instance"] as CardInstance).has_keyword(Mtg.Keyword.FLYING)


## "When an opponent plays a land" — a land DROP (CR 305.1), not a land put
## onto the battlefield by an effect.
static func _opponent_plays_land(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var caster := int(e.data.get("controller", -1))
	return caster >= 0 and caster != s.controller_id


static func _opponent_plays_nonbasic(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance", null)
	return land != null and _opponent_plays_land(g, s, e) \
		and (land.cur_supertypes & Mtg.Supertype.BASIC) == 0


## Veiled Crocodile's state: some player has no cards in hand.
static func _a_hand_is_empty(g: MtgGame, _s: CardInstance, _e: GameEvent) -> bool:
	for p in g.players:
		if p.hand.is_empty():
			return true
	return false


## Hidden Predators' state: an opponent controls a creature with power 4 or
## greater (its live power).
static func _opponent_has_power_four(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	for inst in g.players[g.opponent_of(s.controller_id)].battlefield:
		if inst.is_creature() and not inst.phased_out and inst.cur_power >= 4:
			return true
	return false


## Opal Avenger's state: its controller has 10 or less life.
static func you_have_ten_or_less(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return g.players[s.controller_id].life <= 10


## Lurking Jackals' state: an opponent has 10 or less life.
static func opponent_has_ten_or_less(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	return g.players[g.opponent_of(s.controller_id)].life <= 10


## Lurking Skirge's event: a CREATURE (as it last existed, CR 608.2h — an
## animated land or an Opal counts) went from the battlefield to an
## opponent's graveyard — its OWNER's (CR 400.3); a token goes there too
## before it ceases to exist.
static func creature_to_opponents_graveyard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var dead: CardInstance = e.data.get("instance", null)
	return dead != null and dead != s and (dead.last_types & CREATURE) != 0 \
		and dead.owner_id != s.controller_id


## The trigger context plus "that spell" (Opal Titan, Veiled Sentry): its
## stack object, and its colours and mana value AS IT WAS CAST — read as the
## trigger is put on the stack, so a spell countered before the trigger
## resolves is still described (CR 608.2h). The mana value counts X as
## announced (CR 202.3e).
static func _spell_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var context := F._source_context(g, s, e)
	var spell: CardInstance = e.data.get("instance", null)
	if spell != null:
		var item := g.find_stack_item(spell)
		context["spell_item"] = item.id if item != null else -1
		context["colors"] = spell.cur_colors
		context["mana_value"] = _mana_value(g, spell)
	return context


static func _mana_value(g: MtgGame, spell: CardInstance) -> int:
	return spell.data.cost.mana_value() + g.casting_x(spell) * spell.data.cost.x_count


## "That spell"'s colours ([param key] "colors") or mana value ("mana_value")
## as the ability resolves (CR 608.2h): read LIVE while the spell is still
## the same object on the stack — a Purelace in response makes it white, so
## the Titan gets protection from white, not green.
## SIMPLIFIED (docs/simplified-cards.md, "Opal Titan"): a spell that has
## left the stack is described as it was cast, not as it last existed on
## the stack — a colour changed on the stack and then countered before the
## trigger resolves is not remembered (the stack keeps no last known
## information).
static func _that_spell(g: MtgGame, s: CardInstance, key: String) -> int:
	var ctx := g.trigger_context(s)
	var item_id := int(ctx.get("spell_item", -1))
	for item: StackItem in g.stack:
		if item.id == item_id and item.kind == Mtg.StackKind.SPELL and item.card != null:
			return item.card.cur_colors if key == "colors" else _mana_value(g, item.card)
	return int(ctx.get(key, 0))


# -------------------------------------------------------- the riders --

## Opal Titan: "with protection from each of that spell's colors" — a
## colourless spell gives none.
static func _titan_protection(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var colors := _that_spell(g, s, "colors")
	if colors != 0:
		g.grant_protection_permanently(s, colors)


## Veiled Sentry: an Illusion creature whose power and toughness are each
## that spell's mana value — a 0 makes a 0/0 that dies (CR 704.5f).
static func _sentry(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s) or not s.is_type(ENCHANTMENT):
		return
	var size := _that_spell(g, s, "mana_value")
	make_creature(g, s, size, size, ["illusion"])


## Veiled Apparition's granted "At the beginning of your upkeep, sacrifice
## this creature unless you pay {1}{U}." — a floating layer-6 grant bound to
## the permanent (Musician's shape, ice/_permanents.gd), stamped now.
static func _apparition_upkeep_grant(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var upkeep := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _apparition_upkeep,
		"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.",
		F._your_upkeep).capturing(F._source_context)
	g.continuous.add_floating_static(s, StaticAbility.new(_grant_trigger.bind(s.id, upkeep),
		"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.") \
		.changing_abilities().granting_triggers([Mtg.EventType.UPKEEP_START]),
		D.INDEFINITE, -1, false, s.id)
	g.recalculate()


static func _grant_trigger(g: MtgGame, _source: CardInstance, id: int,
		trigger: TriggeredAbility) -> void:
	var body := g.find_instance(id)
	if body != null and body.zone == Mtg.Zone.BATTLEFIELD and not body.phased_out:
		body.cur_triggered_abilities.append(trigger)


static func _apparition_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return
	var who := int(g.trigger_context(s).get("controller", s.controller_id))
	if not EffectBase.unless_paid(g, who, ManaCost.parse("{1}{U}"),
			"Pay {1}{U} to keep %s?" % s.data.card_name):
		g.sacrifice_permanent(s)


## Veiled Serpent's granted "This creature can't attack unless defending
## player controls an Island." — a floating static bound to the permanent
## writing the live attack ban, stamped now so a Humility that arrives later
## removes it and one already there does not (CR 613.7,
## [method ContinuousEffects.ability_removed_since]). Granted, not printed:
## a dormant Serpent that Opalescence animates has no such clause.
static func _serpent_island_grant(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var stamp := g.continuous.next_timestamp()
	g.continuous.add_floating_static(s, StaticAbility.new(_island_or_stay.bind(s.id, stamp),
		"This creature can't attack unless defending player controls an Island."),
		D.INDEFINITE, -1, false, s.id)
	g.recalculate()


static func _island_or_stay(g: MtgGame, _source: CardInstance, id: int, stamp: int) -> void:
	var serpent := g.find_instance(id)
	if serpent == null or serpent.zone != Mtg.Zone.BATTLEFIELD or serpent.phased_out:
		return
	if g.continuous.ability_removed_since(serpent, stamp):
		return
	for land in g.players[g.opponent_of(serpent.controller_id)].battlefield:
		if land.is_land() and not land.phased_out and land.has_subtype("island"):
			return
	serpent.cur_cant_attack = true


# ------------------------------------------------------- the activations --

## Opal Acrolith's {0}: "This permanent becomes an enchantment." Whatever it
## is now — a creature again becomes a plain enchantment (its 2/4 effect
## still exists and is meaningless while it is no creature, CR 205.1a).
static func _to_enchantment(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if g.is_present(s):
		make_enchantment(g, s)


## Lurking Evil: "This enchantment becomes a 4/4 Phyrexian Horror creature
## with flying." Activated again once it is a creature, the life is paid and
## the same effect is made again (a new timestamp, nothing else).
static func _lurking_evil(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if g.is_present(s):
		make_creature(g, s, 4, 4, ["phyrexian", "horror"], [Mtg.Keyword.FLYING])


## Hidden Stag's second trigger: "Whenever you play a land, if this
## permanent is a creature, it becomes an enchantment."
static func _you_play_a_land_as_a_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return s.is_creature() and int(e.data.get("controller", -1)) == s.controller_id


static func _stag_settles(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and s.is_creature():   # CR 603.4
		make_enchantment(g, s)


## Soul Sculptor: "Target creature becomes an enchantment and loses all
## abilities until a player casts a creature spell." Both halves end on the
## same event, the casting of any player's creature spell — the Sculptor's
## controller's included (CR 601.2i). The removal is bound to the target
## (CR 611.2c) and outlives the Sculptor.
static func _sculpt(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var target := g.find_instance(t.instance_id) if t != null else null
	if target == null or not g.is_present(target):
		return
	var ends := ContinuousEffects.until_spell_cast(CREATURE)
	g.continuous.add_type_change(target.id, {"set_types": ENCHANTMENT}, D.UNTIL_EVENT, -1, ends)
	g.continuous.add_floating_static(s, StaticAbility.removing_all_abilities(
		_only.bind(target.id), "Loses all abilities until a player casts a creature spell."),
		D.UNTIL_EVENT, -1, false, target.id, ends)
	g.log_line("%s becomes an enchantment and loses all abilities until a player casts a creature spell"
		% target.data.card_name, target)
	g.recalculate()


static func _only(_g: MtgGame, _s: CardInstance, inst: CardInstance, id: int) -> bool:
	return inst.id == id
