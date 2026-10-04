extends RefCounted
## Mirage (_misc, Pack 8). Everything else: world enchantments, global effects and one-off rules.
##
## Batch B7 — the replacement and global-rules suite. Most of these cards
## are thin declarations over the Pack 8 engine packages:
## - the DAMAGE REPLACEMENT SUITE (engine/damage_replacements.gd, E5):
##   Shadowbane, Circle of Despair, Reflect Damage ([SourceShieldEffect]),
##   Benevolent Unicorn (a static modifier), Soul Echo ("until your next
##   upkeep", CR 611.2b) and the stack statics of Kaervek's Torch and
##   Torrent of Lava (CR 611.3). Every entry joins the CR 616.1 walk, so the
##   affected player / the affected creature's controller orders it against
##   a Circle of Protection, a prevention pool or Rock Hydra.
## - the player-state rules (E10): Celestial Dawn's layer-5 colour outside
##   the battlefield and its spending rule, Forsaken Wastes' "can't gain
##   life" (CR 119.7).
## - the zone replacements (E7): Forbidden Crypt's "exile instead".
## - E4's "becomes the target of a spell" (Forsaken Wastes).
## The shared "pid" rule of the trigger modules applies here too: a
## triggered ability resolves for the seat that controlled it when it
## triggered (CR 603.3a), even after its source has left (CR 603.6).
const F := preload("res://cards/sets/fem/_rules.gd")
const LOOT := preload("res://cards/sets/atq/jalum_tome.gd")

const BASICS := ["Plains", "Island", "Swamp", "Mountain", "Forest"]


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Benevolent Unicorn":
			c.static_ability(StaticAbility.new(_unicorn,
				"If a spell would deal damage to a permanent or player, it deals that much damage minus 1 to that permanent or player instead."))
		"Celestial Dawn":
			c.static_ability(StaticAbility.new(_dawn_plains, "Lands you control are Plains.").changing_land_types())
			c.static_ability(StaticAbility.new(_dawn_white,
				"Nonland permanents you control are white. The same is true for spells you control and nonland cards you own that aren't on the battlefield.").changing_colors())
			c.static_ability(StaticAbility.new(_dawn_mana,
				"You may spend white mana as though it were mana of any color. You may spend other mana only as though it were colorless mana."))
		"Null Chamber":
			c.as_it_enters(_chamber_names)
			c.bans_playing(_chamber_ban)
		"Shadowbane":
			c.spell(SourceShieldEffect.prevent_to_you_and_your_creatures().with_rider(_shadowbane_rider))
		"Soul Echo":
			c.as_it_enters(_echo_counters)
			c.static_ability(StaticAbility.new(_echo_no_loss, "You don't lose the game for having 0 or less life."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _echo_upkeep,
				"At the beginning of your upkeep, sacrifice this enchantment if there are no echo counters on it. Otherwise, target opponent may choose that for each 1 damage that would be dealt to you until your next upkeep, you remove an echo counter from this enchantment instead.",
				F._your_upkeep).targeting(TargetSpec.opponent(), Callable(),
				"Soul Echo: target opponent chooses how damage to you is dealt"))
		"Bazaar of Wonders":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _bazaar_exile,
				"When this enchantment enters, exile all graveyards.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _bazaar_counter,
				"Whenever a player casts a spell, counter it if a card with the same name is in a graveyard or a nontoken permanent with the same name is on the battlefield.",
				_a_spell_was_cast))
		"Forbidden Crypt":
			c.replaces_draws(_crypt_draw, _crypt_applies)
			c.static_ability(StaticAbility.new(_crypt_exile,
				"If a card would be put into your graveyard from anywhere, exile that card instead."))
		"Forsaken Wastes":
			c.static_ability(StaticAbility.new(_no_life_gain, "Players can't gain life."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wastes_upkeep,
				"At the beginning of each player's upkeep, that player loses 1 life."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TARGET, _wastes_targeted,
				"Whenever this enchantment becomes the target of a spell, that spell's controller loses 5 life.",
				_targeted_by_a_spell))
		"Tombstone Stairwell":
			CumulativeUpkeep.attach(c, "{1}{B}")
			var tombspawn := CardData.new("Tombspawn", "", Mtg.CardType.CREATURE).pt(2, 2) \
				.with_colors(Mtg.ManaColor.B).with_subtypes(["zombie"]) \
				.with_keywords([Mtg.Keyword.HASTE]).oracle("Haste")
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _stairwell_rise.bind(tombspawn),
				"At the beginning of each upkeep, if this enchantment is on the battlefield, each player creates a 2/2 black Zombie creature token with haste named Tombspawn for each creature card in their graveyard."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _stairwell_fall,
				"At the beginning of each end step, destroy all tokens created with this enchantment. They can't be regenerated.")
				.capturing(_stairwell_context))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _stairwell_fall,
				"When this enchantment leaves the battlefield, destroy all tokens created with this enchantment. They can't be regenerated.",
				F._self_enter).capturing(_stairwell_leave_context))
		"Chaosphere":
			c.static_ability(StaticAbility.new(_chaosphere,
				"Creatures with flying can block only creatures with flying. Creatures without flying have reach.").changing_abilities().reading_abilities())
		"Kaervek's Torch":
			c.spell(DamageEffect.new(0).any_target().x_damage())
			c.with_targeting_surcharge(2)
		"Torrent of Lava":
			c.spell(DamageAllEffect.new(0, "each creature without flying", _without_flying).x_damage())
			c.stack_static(StaticAbility.new(_torrent_grant,
				"As long as Torrent of Lava is on the stack, each creature has \"{T}: Prevent the next 1 damage that would be dealt to this creature by Torrent of Lava this turn.\""))
		"Hall of Gemstone":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _hall_choose,
				"At the beginning of each player's upkeep, that player chooses a color. Until end of turn, lands tapped for mana produce mana of the chosen color instead of any other color."))
		"Circle of Despair":
			c.activated(ActivatedAbility.new("{1}", false, [SourceShieldEffect.prevent_to_target()],
				"{1}, Sacrifice a creature: The next time a source of your choice would deal damage to any target this turn, prevent that damage.")
				.with_sacrifice_of("creature", _is_creature))
		"Reflect Damage":
			c.spell(SourceShieldEffect.reflect())
		"Unfulfilled Desires":
			c.activated(ActivatedAbility.new("{1}", false, [LOOT.LootEffect.new()],
				"{1}, Pay 1 life: Draw a card, then discard a card.").with_life_cost(1))
		_: return false
	return true


# ------------------------------------------------------------- shared --

## The seat a resolving trigger acts for (CR 603.3a) — its controller when
## it triggered, even if the source has left since.
static func _pid(g: MtgGame, s: CardInstance) -> int:
	var pid := g.current_resolution_controller()
	return pid if pid >= 0 else s.controller_id


static func _is_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


static func _without_flying(inst: CardInstance) -> bool:
	return not inst.has_keyword(Mtg.Keyword.FLYING)


## A basic land CARD name ("other than a basic land card name") — the five
## basics and their snow-covered kin, read off the registry's card.
static func _is_basic_land_name(card_name: String) -> bool:
	if BASICS.has(card_name):
		return true
	var data := CardRegistry.get_card(card_name)
	return data != null and data.is_land() and (data.supertypes & Mtg.Supertype.BASIC) != 0


# --------------------------------------------------- Benevolent Unicorn --

## CR 614.1a: a modifier on every SPELL's damage, any victim. Two Unicorns
## are two replacements, each applied once (CR 616.1f).
static func _unicorn(g: MtgGame, s: CardInstance) -> void:
	g.add_static_damage_effect(s, {"kind": &"modify", "delta": -1, "spell_only": true,
		"desc": "Benevolent Unicorn: a spell deals 1 less damage"})


# -------------------------------------------------------- Celestial Dawn --

static func _dawn_plains(g: MtgGame, s: CardInstance) -> void:
	for land in g.players[s.controller_id].battlefield:
		if land.is_land():
			land.become_basic_land_type("plains", Mtg.ManaColor.W)


## Layer 5, on the battlefield and off it (E10's set_offzone_color: the
## nonland cards the controller OWNS in every other zone and the spells
## they CONTROL on the stack).
static func _dawn_white(g: MtgGame, s: CardInstance) -> void:
	for perm in g.players[s.controller_id].battlefield:
		if not perm.is_land():
			perm.cur_colors = Mtg.ManaColor.W
	g.set_offzone_color(s.controller_id, Mtg.ManaColor.W)


static func _dawn_mana(g: MtgGame, s: CardInstance) -> void:
	g.set_mana_spending_rule(s.controller_id, Mtg.ManaColor.W,
		Mtg.ManaColor.U | Mtg.ManaColor.B | Mtg.ManaColor.R | Mtg.ManaColor.G)


# ----------------------------------------------------------- Null Chamber --

## "As this enchantment enters, you and an opponent each choose a card name
## other than a basic land card name" — a replacement (CR 614.1c), so the
## ban is in force the moment the Chamber is. WHAT MAY BE NAMED follows the
## owner's naming ruling (2026-09-07, leg/petra_sphinx.gd): a short list
## from a decklist the chooser could see before the game — each player names
## from the OTHER seat's deck, which is the only deck whose names it can
## matter to ban. Basic land names are never offered.
static func _chamber_names(g: MtgGame, s: CardInstance, pid: int) -> void:
	var chosen: Array[String] = []
	for chooser in [pid, g.opponent_of(pid)]:
		var victim: int = g.opponent_of(chooser)
		var names := _nameable(g, victim)
		if names.is_empty():
			g.log_line("%s has no card name to choose for Null Chamber" % g.players[chooser].player_name)
			continue
		var pick := g.agents[chooser].choose_option(g, chooser, names,
			"Null Chamber: choose a card name (spells with it can't be cast, lands with it can't be played)", 0)
		if pick < 0 or pick >= names.size():
			pick = 0
		chosen.append(names[pick])
		g.log_line("%s chooses %s for Null Chamber" % [g.players[chooser].player_name, names[pick]])
	g._rec(s, &"memory")
	s.memory["chamber_names"] = chosen


## The names of [param who]'s decklist (each once) that are not basic land
## names — most copies not yet seen in a public zone first. Only PUBLIC
## zones are subtracted: never a hand, never a library's order (fair play,
## CONTRIBUTING rule 8).
static func _nameable(g: MtgGame, who: int) -> Array[String]:
	var left := {}
	for n in g.players[who].deck_names:
		if not _is_basic_land_name(n):
			left[n] = int(left.get(n, 0)) + 1
	for p in g.players:
		for zone in [p.battlefield, p.graveyard, p.exile]:
			for i in zone:
				if i.is_token or i.face_down or i.owner_id != who: continue
				if left.has(i.data.card_name):
					left[i.data.card_name] = maxi(int(left[i.data.card_name]) - 1, 0)
	var names: Array[String] = []
	for n in left: names.append(String(n))
	names.sort_custom(func(a: String, b: String) -> bool:
		if int(left[a]) != int(left[b]): return int(left[a]) > int(left[b])
		return a < b)
	return names


## The play ban every Null Chamber radiates (CardData.play_ban): a name
## any Chamber on the battlefield chose — live, so a silenced or phased-out
## Chamber bans nothing.
static func _chamber_ban(g: MtgGame, _pid: int, data: CardData) -> bool:
	for inst in g.all_battlefield():
		if inst.phased_out or inst.cur_abilities_silenced or not inst.memory.has("chamber_names"):
			continue
		var names: Array = inst.memory.get("chamber_names", [])
		if names.has(data.card_name):
			return true
	return false


# ------------------------------------------------------------- Shadowbane --

## "If damage from a black source is prevented this way, you gain that much
## life." The source's colour is read as it deals the damage (last known
## information for a spell that has resolved).
static func _shadowbane_rider(g: MtgGame, packet: DamagePacket, amount: int,
		_effect_source: CardInstance, pid: int) -> void:
	if (g.damage_source_colors(packet.source) & Mtg.ManaColor.B) != 0:
		g.adjust_life(pid, amount)


# -------------------------------------------------------------- Soul Echo --

## "This enchantment enters with X echo counters on it" — a replacement
## (CR 614.1c) reading the X the cast recorded (Rock Hydra's shape).
static func _echo_counters(g: MtgGame, inst: CardInstance, _pid: int) -> void:
	var x := int(inst.memory.get("x_value", 0))
	if x > 0:
		g.add_counters(inst, "echo", x)


static func _echo_no_loss(g: MtgGame, s: CardInstance) -> void:
	g.players[s.controller_id].cant_lose_to_life = true


## The upkeep trigger: sacrifice the Echo when it has no echo counters;
## otherwise the TARGET OPPONENT chooses whether, until "your" next upkeep,
## each 1 damage that would be dealt to you removes an echo counter instead
## (CR 611.2b: the registry's `lasts: &"upkeep"`). The replacement is
## RULED here, as Forge's script reads the card: it replaces the WHOLE
## damage event (CR 614.6 — a replacement whose instead-action is partly
## impossible still replaces), removing as many counters as there are, and
## it lives only while that same Echo is on the battlefield. A replacement,
## not prevention: damage that can't be prevented is replaced too.
static func _echo_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s):
		return
	var pid := _pid(g, s)
	if int(s.counters.get("echo", 0)) <= 0:
		if s.controller_id == pid:
			g.sacrifice_permanent(s)
		return
	var targets := g.current_targets()
	if targets.is_empty() or targets[0] == null or not targets[0].is_player:
		return
	var opp: int = targets[0].player_id
	if not g.agents[opp].choose_yes_no(g, opp,
			"Soul Echo: until %s's next upkeep, should each 1 damage dealt to them remove an echo counter instead?"
			% g.players[pid].player_name, true):
		g.log_line("%s lets damage to %s be dealt as usual" % [g.players[opp].player_name, g.players[pid].player_name])
		return
	g.add_damage_effect({"kind": &"replace", "controller": pid, "card": "Soul Echo",
		"victims": [TargetRef.player(pid)], "lasts": &"upkeep", "lasts_pid": pid,
		"desc": "Soul Echo: each 1 damage removes an echo counter instead",
		"filter": _echo_alive.bind(s.id, s.layer_timestamp),
		"apply": _echo_instead.bind(s.id, s.layer_timestamp)})
	g.log_line("%s chooses: damage to %s removes echo counters until their next upkeep" % [
		g.players[opp].player_name, g.players[pid].player_name])


static func _echo_alive(g: MtgGame, _packet: DamagePacket, id: int, stamp: int) -> bool:
	var echo := g.find_instance(id)
	return echo != null and echo.zone == Mtg.Zone.BATTLEFIELD and echo.layer_timestamp == stamp


static func _echo_instead(g: MtgGame, packet: DamagePacket, id: int, _stamp: int) -> int:
	var amount := packet.remaining()
	var echo := g.find_instance(id)
	g._rec(packet, &"amount")
	packet.amount -= amount
	var removed := mini(amount, int(echo.counters.get("echo", 0)))
	if removed > 0:
		g.remove_counters(echo, "echo", removed)
	g.log_line("Soul Echo: %d damage removes %d echo counter(s) instead" % [amount, removed])
	return 0


# ------------------------------------------------------ Bazaar of Wonders --

static func _bazaar_exile(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	for p in g.players:
		for card in p.graveyard.duplicate():
			g.exile_from_graveyard(card)


static func _a_spell_was_cast(_g: MtgGame, _s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") is CardInstance


## "Counter it if ..." — checked as the trigger RESOLVES (not an
## intervening if): a card of that name in either graveyard, or a NONTOKEN
## permanent of that name. A face-down permanent has no name (CR 708.2).
static func _bazaar_counter(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var spell: CardInstance = e.data.get("instance")
	if spell == null or spell.zone != Mtg.Zone.STACK or g.find_stack_item(spell) == null:
		return
	var name := spell.data.card_name
	var hit := false
	for p in g.players:
		for card in p.graveyard:
			if card.data.card_name == name:
				hit = true
	for perm in g.all_battlefield():
		if not perm.is_token and not perm.face_down and perm.data.card_name == name:
			hit = true
	if hit:
		g.log_line("Bazaar of Wonders counters %s" % name)
		g.counter_spell(spell)


# -------------------------------------------------------- Forbidden Crypt --

## The pure half (CR 616.1): every draw of the Crypt's controller, while
## the Crypt has its abilities.
static func _crypt_applies(_g: MtgGame, s: CardInstance, pid: int, _ctx: Dictionary) -> bool:
	return pid == s.controller_id and not s.cur_abilities_silenced and not s.phased_out


## "If you would draw a card, return a card from your graveyard to your
## hand instead. If you can't, you lose the game." The card is the
## player's choice (its graveyard is public); best first for the hint.
static func _crypt_draw(g: MtgGame, s: CardInstance, pid: int, ctx: Dictionary) -> bool:
	if not _crypt_applies(g, s, pid, ctx):
		return false
	var pile: Array[CardInstance] = g.players[pid].graveyard.duplicate()
	if pile.is_empty():
		g.log_line("Forbidden Crypt: %s has no card to return instead of drawing" % g.players[pid].player_name)
		g.lose_game(pid, "Forbidden Crypt")
		return true
	pile.sort_custom(_better_card)
	var pick := g.agents[pid].choose_card(g, pid, pile,
		"Forbidden Crypt: return a card from your graveyard to your hand instead of drawing", false, false, true)
	if pick == null or not pile.has(pick):
		pick = pile[0]
	g.log_line("Forbidden Crypt: %s returns %s instead of drawing" % [g.players[pid].player_name, pick.data.card_name])
	g.return_from_graveyard_to_hand(pick)
	return true


## A spell before a land, then the larger mana value — a public-zone sort.
static func _better_card(a: CardInstance, b: CardInstance) -> bool:
	if a.data.is_land() != b.data.is_land():
		return not a.data.is_land()
	var av := a.data.cost.mana_value()
	var bv := b.data.cost.mana_value()
	if av != bv:
		return av > bv
	return a.id < b.id


static func _crypt_exile(g: MtgGame, s: CardInstance) -> void:
	g.players[s.controller_id].graveyard_becomes_exile = true


# -------------------------------------------------------- Forsaken Wastes --

static func _no_life_gain(g: MtgGame, _s: CardInstance) -> void:
	for p in g.players:
		p.cant_gain_life = true


## "that player loses 1 life" — the player whose upkeep it is.
static func _wastes_upkeep(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	g.adjust_life(int(e.data.get("player", g.active_player)), -1)


static func _targeted_by_a_spell(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s and bool(e.data.get("is_spell", false))


static func _wastes_targeted(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.get("controller", -1))
	if who >= 0:
		g.adjust_life(who, -5)


# ---------------------------------------------------- Tombstone Stairwell --

## The intervening "if this enchantment is on the battlefield" (CR 603.4)
## is the trigger's own zone plus this recheck. Each player creates the
## tokens for the creature CARDS in their own graveyard, counted now; the
## Stairwell remembers every token it made (instance ids, never reused).
static func _stairwell_rise(g: MtgGame, s: CardInstance, _e: GameEvent, token: CardData) -> void:
	if not F._same_trigger_source(g, s):
		return
	var made: Array = s.memory.get("tombspawn", []).duplicate()
	for p in g.players:
		var n := 0
		for card in p.graveyard:
			if card.is_creature():
				n += 1
		if n > 0:
			for t in g.create_token(p.id, token, n):
				made.append(t.id)
	g._rec(s, &"memory")
	s.memory["tombspawn"] = made


static func _stairwell_context(_g: MtgGame, s: CardInstance, _e: GameEvent) -> Dictionary:
	return {"timestamp": s.layer_timestamp, "controller": s.controller_id,
		"tombspawn": s.memory.get("tombspawn", []).duplicate()}


## The leave trigger reads the memory the Stairwell carried as it left.
static func _stairwell_leave_context(_g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var parting: Dictionary = e.data.get("memory", {})
	return {"timestamp": s.layer_timestamp, "controller": int(e.data.get("from_controller", s.controller_id)),
		"tombspawn": parting.get("tombspawn", []).duplicate()}


## "Destroy all tokens created with this enchantment. They can't be
## regenerated." One resolution, one simultaneous bracket.
static func _stairwell_fall(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ids: Array = g.trigger_context(s).get("tombspawn", [])
	g.begin_simultaneous()
	for id in ids:
		var token := g.find_instance(int(id))
		if token != null and token.zone == Mtg.Zone.BATTLEFIELD:
			g.destroy(token, false)
	g.end_simultaneous()
	if F._same_trigger_source(g, s) and not ids.is_empty():
		var left: Array = []
		for id in s.memory.get("tombspawn", []):
			var token := g.find_instance(int(id))
			if token != null and token.zone == Mtg.Zone.BATTLEFIELD:
				left.append(id)
		g._rec(s, &"memory")
		s.memory["tombspawn"] = left


# -------------------------------------------------------------- Chaosphere --

## Layer 6: every creature without flying gains REACH; every creature gets
## the block rule "if this has flying, it can block only creatures with
## flying", read LIVE at the declaration (both creatures' flying) and
## composed with whatever "can't block" filter it already had. The blocker
## is bound as a WeakRef: a Callable on the instance holding the instance
## itself would be a reference cycle (a leak at exit).
##
## WHO LACKS FLYING is asked after the rest of layer 6 has settled it
## (`reading_abilities()`, CR 613.8a): "creatures without flying have
## reach" depends on every effect that grants or removes flying, so an
## Earthbind or a Mist Dragon's "{0}: loses flying" made after the
## Chaosphere still leaves a creature without flying — with reach — and a
## Jump made after it leaves one WITH flying and nothing from here.
static func _chaosphere(g: MtgGame, _s: CardInstance) -> void:
	for inst in g.all_battlefield():
		if not inst.is_creature():
			continue
		if not inst.has_keyword(Mtg.Keyword.FLYING) and not inst.cur_keywords.has(Mtg.Keyword.REACH):
			inst.cur_keywords.append(Mtg.Keyword.REACH)
		var me: WeakRef = weakref(inst)
		inst.cur_cant_block_filter = _flyer_blocks_flyers.bind(me, inst.cur_cant_block_filter)


static func _flyer_blocks_flyers(attacker: CardInstance, me: WeakRef, before: Callable) -> bool:
	if before.is_valid() and bool(before.call(attacker)):
		return true
	var blocker: CardInstance = me.get_ref()
	return blocker != null and blocker.has_keyword(Mtg.Keyword.FLYING) \
		and not attacker.has_keyword(Mtg.Keyword.FLYING)


# --------------------------------------------------------- Torrent of Lava --

## CR 611.3: while the spell is on the stack, each creature has the
## ability. Built per call — it binds this spell's id.
static func _torrent_grant(g: MtgGame, spell: CardInstance) -> void:
	for inst in g.all_battlefield():
		if inst.is_creature():
			inst.cur_activated_abilities.append(ActivatedAbility.new("", true, [TorrentShield.new(spell.id)],
				"{T}: Prevent the next 1 damage that would be dealt to this creature by Torrent of Lava this turn."))


## "{T}: Prevent the next 1 damage that would be dealt to this creature by
## Torrent of Lava this turn" — a metered shield keyed to that one spell
## (and the card it is, CR 609.7a), legal in the 1997 prevention window.
class TorrentShield extends EffectBase:
	var spell_id := -1

	func _init(p_spell: int) -> void:
		spell_id = p_spell
		is_damage_prevention = true
		ai_helpful = true

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var torrent := game.find_instance(spell_id)
		if torrent == null or source == null or not game.is_present(source):
			return
		game.prevent_next_damage_points(controller, "Torrent of Lava", source, 1, torrent)

	func describe() -> String:
		return "prevent the next 1 damage that would be dealt to this creature by Torrent of Lava this turn"


# ------------------------------------------------------- Hall of Gemstone --

## "That player chooses a color. Until end of turn, lands tapped for mana
## produce mana of the chosen color instead of any other color." Every land
## on the table, both seats', for the rest of the turn — a floating static
## (it outlives the Hall, CR 611.2a). Colorless is not a color: a land's
## {C} ability is untouched.
static func _hall_choose(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("player", g.active_player))
	var color := g.agents[pid].choose_color(g, pid, "Hall of Gemstone: choose a color", _hall_hint(g, pid))
	if color not in Mtg.WUBRG:
		color = _hall_hint(g, pid)
	g.log_line("%s chooses %s for Hall of Gemstone" % [g.players[pid].player_name,
		String(Mtg.COLOR_NAMES.get(color, "?"))])
	g.continuous.add_floating_static(s, StaticAbility.new(_hall_lands.bind(color),
		"Until end of turn, lands tapped for mana produce mana of the chosen color instead of any other color."))
	g.recalculate()


## The seat's own hand's coloured pips (its own hand is fair to read), then
## the colours of the permanents it controls.
static func _hall_hint(g: MtgGame, pid: int) -> int:
	var counts := {}
	for color in Mtg.WUBRG:
		counts[color] = 0
	for card in g.players[pid].hand:
		for color in card.data.cost.colored:
			if counts.has(int(color)):
				counts[int(color)] += 2 * int(card.data.cost.colored[color])
	for perm in g.players[pid].battlefield:
		for color in Mtg.WUBRG:
			if (perm.cur_colors & color) != 0:
				counts[color] += 1
	var best: int = Mtg.ManaColor.G
	var most := 0
	for color in Mtg.WUBRG:
		if int(counts[color]) > most:
			most = int(counts[color])
			best = color
	return best


## "Instead of any other COLOR": only coloured mana changes — a Mishra's
## Factory's {C} ability is left as it is, and a Karoo's {C}{U} makes
## {C}{R}, not {R}{R} (ManaAbility.forcing_color's colours-only mode; CR
## 105.1/105.2c — colourless is not a colour).
static func _hall_lands(g: MtgGame, _s: CardInstance, color: int) -> void:
	for land in g.all_battlefield():
		if not land.is_land():
			continue
		var out: Array[ManaAbility] = []
		for ability in land.cur_mana_abilities:
			if ability.taps_source and _makes_color(ability):
				out.append(ability.forcing_color(color, false, true))
			else:
				out.append(ability)
		land.cur_mana_abilities = out


static func _makes_color(ability: ManaAbility) -> bool:
	if ability.dynamic_color.is_valid() or ability.color_options.is_valid():
		return true
	for pair in ability.produces:
		if int(pair[0]) != Mtg.ManaColor.C:
			return true
	return false
