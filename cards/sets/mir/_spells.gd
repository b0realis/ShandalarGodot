extends RefCounted
## Mirage (_spells, Pack 8). Instants and sorceries: one-shot spell effects,
## modes, X spells and their targets.
##
## Effects are TYPED wherever the engine has the shape — the fair AI reads
## them (engine/ai/effect_intent.gd) — and a card-local class subclasses the
## typed effect it most resembles (a DestroyEffect that also pays out, a
## DamageAllEffect whose amount varies by colour), so its intent still
## reads as removal, a sweeper or a pump. Every choice is the resolving
## seat's own question through its DecisionAgent (CR 608.2), with a hint
## computed from public information only. Targeting restrictions live in
## the TargetSpec, never in resolve() (docs/adding-cards.md).
##
## Dissipate's "exile it instead of putting it into its owner's graveyard"
## is CounterEffect.to_exile() — a replacement on the countered card's
## destination (CR 614.1), never a visit to the graveyard.
const F := preload("res://cards/sets/fem/_rules.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Afterlife": c.spell(Afterlife.new())
		"Disempower": c.spell(ToLibraryTop.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact or enchantment", P.artifact_or_enchantment)))
		"Illumination": c.spell(Illumination.new())
		"Ivory Charm":
			c.mode("All creatures get -2/-0 until end of turn", [MassPumpEffect.new(-2, 0, "all creatures")])
			c.mode("Tap target creature", [TapEffect.new(TargetSpec.creature())])
			c.mode("Prevent the next 1 damage that would be dealt to any target this turn",
				[PreventDamageEffect.new(1).any_target()])
			c.with_ai_mode(_ivory_mode)
		"Jabari's Influence":
			c.castable_only_when(_after_combat)
			c.spell(Influence.new())
		"Mangara's Blessing":
			c.spell(GainLifeEffect.new(5))
			c.triggered(TriggeredAbility.new(Mtg.EventType.CARD_DISCARDED, _blessing_returns,
				"When a spell or ability an opponent controls causes you to discard this card, you gain 2 life, and you return this card from your graveyard to your hand at the beginning of the next end step.",
				_hostile_discard).capturing(_discard_context))
		# ------------------------------------------------------------- blue
		"Dissipate": c.spell(CounterEffect.new().to_exile())
		"Dream Cache":
			c.spell(DrawEffect.new(3))
			c.spell(F.Action.new(_dream_cache, "put two cards from your hand both on top or both on the bottom of your library", null, true))
		"Ether Well": c.spell(EtherWell.new())
		"Flash": c.spell(F.Action.new(_flash, "you may put a creature card from your hand onto the battlefield; sacrifice it unless you pay its mana cost reduced by {2}", null, true))
		"Jolt": c.spell(TapOrUntap.new()).spell(DelayedDrawEffect.new())
		"Meddle": c.spell(F.Action.new(_meddle, "if target spell has only one target and it is a creature, change that target to another creature", TargetSpec.spell()))
		"Mind Bend": c.spell(MindBend.new())
		"Political Trickery":
			var give := LandSlot.new()
			c.spell(give).spell(LandSwap.new(give.target_spec))
		"Polymorph": c.spell(Polymorph.new())
		"Prismatic Lace": c.spell(PrismaticLace.new())
		"Psychic Transfer": c.spell(PsychicTransfer.new())
		"Tidal Wave": c.spell(TidalWave.new())
		# ------------------------------------------------------------ black
		"Ashen Powder":
			var raise := ReturnFromGraveyardEffect.new().to_battlefield()
			raise.target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD,
				"target creature card in an opponent's graveyard").with_source_filter(P.opponent_owned)
			c.spell(raise)
		"Bone Harvest": c.spell(GraveToTop.new()).spell(DelayedDrawEffect.new())
		"Choking Sands": c.spell(ChokingSands.new())
		"Ebony Charm":
			var loss := GainLifeEffect.new(-1)
			loss.target_spec = TargetSpec.opponent()
			c.mode("Target opponent loses 1 life and you gain 1 life", [loss, GainLifeEffect.new(1)])
			c.mode("Exile up to three target cards from a single graveyard", [GraveExile.new()])
			c.mode("Target creature gains fear until end of turn", [PumpEffect.new(0, 0, [Mtg.Keyword.FEAR])])
			c.with_ai_mode(_first_mode)
		"Infernal Contract": c.spell(DrawEffect.new(4)).spell(HalfLife.new())
		"Kaervek's Hex": c.spell(ColorSweep.new(1, "each nonblack creature and 1 more to each green creature", P.nonblack, P.green))
		"Nocturnal Raid": c.spell(MassPumpEffect.new(2, 0, "black creatures").with_filter(P.black))
		"Painful Memories": c.spell(F.Action.new(_painful_memories, "look at target opponent's hand and put a card from it on top of their library", TargetSpec.opponent()))
		"Reign of Terror": c.spell(ReignOfTerror.new())
		"Shallow Grave": c.spell(F.Action.new(_shallow_grave, "return the top creature card of your graveyard to the battlefield with haste; exile it at the beginning of the next end step", null, true))
		"Soul Rend": c.spell(SoulRend.new()).spell(DelayedDrawEffect.new())
		"Soulshriek": c.spell(Soulshriek.new())
		"Stupor": c.spell(Stupor.new())
		# -------------------------------------------------------------- red
		"Builder's Bane": c.spell(BuildersBane.new())
		"Chaos Charm":
			c.mode("Destroy target Wall", [DestroyEffect.new(TargetSpec.creature("target Wall", P.wall)
				.only_walls().because(TargetSpec.WHY["walls"]))])
			c.mode("Chaos Charm deals 1 damage to target creature", [DamageEffect.new(1).target_creature()])
			c.mode("Target creature gains haste until end of turn", [PumpEffect.new(0, 0, [Mtg.Keyword.HASTE])])
			c.with_ai_mode(_chaos_charm_mode)
		"Cinder Cloud": c.spell(DeathBurn.new(TargetSpec.creature(), true))
		"Final Fortune": c.spell(FinalTurn.new())
		"Goblin Scouts":
			var scouts := CreateTokenEffect.new("Goblin Scout", 1, 1, Mtg.ManaColor.R, "goblin", 3)
			scouts.token.with_subtypes(["scout"]).with_landwalk(["mountain"])
			c.spell(scouts)
		"Hammer of Bogardan":
			c.spell(DamageEffect.new(3).any_target())
			c.activated(F._ability("{2}{R}{R}{R}", false, F.Action.new(_hammer_home,
				"return this card from your graveyard to your hand. Activate only during your upkeep", null, true))
				.from_graveyard().during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Reign of Chaos":
			c.mode("Destroy target Plains and target white creature", [
				DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Plains", P.plains).because(TargetSpec.WHY["subtype"])),
				DestroyEffect.new(TargetSpec.creature("target white creature", P.white))])
			c.mode("Destroy target Island and target blue creature", [
				DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Island", P.island).because(TargetSpec.WHY["subtype"])),
				DestroyEffect.new(TargetSpec.creature("target blue creature", P.blue))])
			c.with_ai_mode(_reign_of_chaos_mode)
		"Sirocco": c.spell(F.Action.new(_sirocco, "target player reveals their hand and discards each blue instant card unless they pay 4 life for it", TargetSpec.player()))
		"Telim'Tor's Edict":
			c.spell(ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target permanent you own or control").with_source_filter(P.own_or_control)))
			c.spell(DelayedDrawEffect.new())
		"Volcanic Geyser": c.spell(DamageEffect.new(0).any_target().x_damage())
		# ------------------------------------------------------------ green
		"Early Harvest": c.spell(F.Action.new(_early_harvest, "target player untaps all basic lands they control", TargetSpec.player(), true))
		"Fallow Earth": c.spell(ToLibraryTop.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", P.land)))
		"Lure of Prey":
			c.castable_only_when(_opponent_cast_creature)
			c.spell(F.Action.new(_lure_of_prey, "you may put a green creature card from your hand onto the battlefield", null, true))
		"Seedling Charm":
			c.mode("Return target Aura attached to a creature to its owner's hand", [ReturnToHandEffect.new(
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target Aura attached to a creature", P.aura).with_game_filter(P.on_creature))])
			c.mode("Regenerate target green creature", [RegenerateEffect.new().target_creature("target green creature", P.green)])
			c.mode("Target creature gains trample until end of turn", [PumpEffect.new(0, 0, [Mtg.Keyword.TRAMPLE])])
			c.with_ai_mode(_seedling_mode)
		"Seeds of Innocence": c.spell(SeedsOfInnocence.new())
		"Serene Heart": c.spell(DestroyAllEffect.new("all Auras", P.aura))
		"Superior Numbers": c.spell(Numbers.new()).spell(OpponentSlot.new())
		"Tranquil Domain": c.spell(DestroyAllEffect.new("all non-Aura enchantments", P.non_aura_enchantment))
		"Tropical Storm": c.spell(ColorSweep.new(0, "each creature with flying and 1 more to each blue creature", P.flying, P.blue).x_damage())
		"Unyaro Bee Sting": c.spell(DamageEffect.new(2).any_target())
		"Waiting in the Weeds": c.spell(WeedCats.new())
		# ------------------------------------------------------------- gold
		"Energy Bolt":
			c.mode("Energy Bolt deals X damage to target player", [DamageEffect.new(0).target_player().x_damage()])
			c.mode("Target player gains X life", [GainLifeEffect.new(0).target_player().x_amount()])
			c.with_ai_mode(_first_mode)
		"Kaervek's Purge": c.spell(DeathBurn.new(TargetSpec.creature("target creature with mana value X")
			.with_source_filter(P.mana_value_x), false))
		"Prismatic Boon": c.spell(PrismaticBoon.new())
		"Savage Twister": c.spell(DamageAllEffect.new(0).x_damage())
		"Sealed Fate": c.spell(F.Action.new(_sealed_fate, "look at the top X cards of target opponent's library, exile one of them and put the rest back on top in any order", TargetSpec.opponent()))
		"Vitalizing Cascade": c.spell(Cascade.new())
		_: return false
	return true


# ================================================================ predicates

## Static predicates shared by the specs above and by the inner classes
## below (a sibling class is reachable from every inner class by name).
## Instance tests read LIVE characteristics (cur_*), never printed data,
## except where the object is a card in a hidden zone.
class P:
	static func color(i: CardInstance, mask: int) -> bool: return (i.cur_colors & mask) != 0
	static func white(i: CardInstance) -> bool: return color(i, Mtg.ManaColor.W)
	static func blue(i: CardInstance) -> bool: return color(i, Mtg.ManaColor.U)
	static func black(i: CardInstance) -> bool: return color(i, Mtg.ManaColor.B)
	static func green(i: CardInstance) -> bool: return color(i, Mtg.ManaColor.G)
	static func nonblack(i: CardInstance) -> bool: return not black(i)
	static func flying(i: CardInstance) -> bool: return i.has_keyword(Mtg.Keyword.FLYING)
	static func land(i: CardInstance) -> bool: return i.is_land()
	static func artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
	static func artifact_or_enchantment(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_type(Mtg.CardType.ENCHANTMENT)
	static func artifact_creature_or_land(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ARTIFACT) or i.is_creature() or i.is_land()
	static func aura(i: CardInstance) -> bool: return i.is_aura()
	static func non_aura_enchantment(i: CardInstance) -> bool:
		return i.is_type(Mtg.CardType.ENCHANTMENT) and not i.is_aura()
	static func wall(i: CardInstance) -> bool: return i.has_subtype("wall")
	static func plains(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("plains")
	static func island(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("island")
	static func non_swamp_land(i: CardInstance) -> bool: return i.is_land() and not i.has_subtype("swamp")
	static func basic(i: CardInstance) -> bool: return (i.cur_supertypes & Mtg.Supertype.BASIC) != 0
	static func nonartifact_nonblack(i: CardInstance) -> bool:
		return not i.is_type(Mtg.CardType.ARTIFACT) and not black(i)
	static func green_or_white_creature(i: CardInstance) -> bool:
		return i.is_creature() and color(i, Mtg.ManaColor.G | Mtg.ManaColor.W)

	## "you control" / "an opponent controls" / "you own" are the CASTER's
	## (CR 109.5): the stack item's controller while it resolves.
	static func yours(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s == null or i.controller_id == g.controller_acting_for(s)
	static func theirs(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s == null or i.controller_id != g.controller_acting_for(s)
	static func own_or_control(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		if s == null: return true
		var pid := g.controller_acting_for(s)
		return i.owner_id == pid or i.controller_id == pid
	static func opponent_owned(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return s == null or i.owner_id != g.controller_acting_for(s)
	## "target creature with mana value X" — X is the spell's own, asked
	## through casting_x so the AI's prospective X is honoured too.
	static func mana_value_x(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return i.data.cost.mana_value() == g.casting_x(s)
	## "that attacked you this turn" (Jabari's Influence). In a duel only
	## the ACTIVE player's creatures attack, and they attack the other
	## seat; attacked_this_turn is cleared at its controller's untap, so
	## an attacker from an earlier turn of theirs never qualifies here.
	static func attacked_you(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return i.attacked_this_turn and s != null and g.active_player != g.controller_acting_for(s) \
			and i.controller_id == g.active_player
	static func on_creature(g: MtgGame, i: CardInstance) -> bool:
		if i.attached_to == -1: return false
		var host := g.find_instance(i.attached_to)
		return host != null and host.zone == Mtg.Zone.BATTLEFIELD and host.is_creature()
	## "a single graveyard": every card of the group shares the first one's owner.
	static func same_graveyard(g: MtgGame, _s: CardInstance, ref: TargetRef, earlier: Array) -> bool:
		if earlier.is_empty(): return true
		var first := g.find_instance(earlier[0].instance_id)
		var this := g.find_instance(ref.instance_id)
		return first != null and this != null and first.owner_id == this.owner_id

	## A card's worth to whoever holds it — the AI's hint for which card a
	## look-and-choose effect picks. Public facts only: its own costs and
	## its owner's land count.
	static func card_value(g: MtgGame, card: CardInstance) -> float:
		if card.data.is_land():
			var lands := 0
			for i in g.players[card.owner_id].battlefield:
				if i.is_land(): lands += 1
			return 3.5 if lands < 5 else 0.5
		return 2.0 + float(card.data.cost.mana_value())

	## [param cards] best first (for the holder).
	static func best_first(g: MtgGame, cards: Array[CardInstance]) -> Array[CardInstance]:
		var out: Array[CardInstance] = []
		out.assign(cards)
		out.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return card_value(g, a) > card_value(g, b))
		return out

	## The colour the [param pid]'s opponent shows most of on the battlefield.
	static func enemy_main_color(g: MtgGame, pid: int) -> int:
		var best: int = Mtg.ManaColor.R
		var most := -1
		for c in Mtg.WUBRG:
			var n := 0
			for i in g.players[g.opponent_of(pid)].battlefield:
				if (i.cur_colors & c) != 0: n += 1
			if n > most:
				most = n
				best = c
		return best

	## Cost text for a prompt ("{G}", "{1}{W}{W}").
	static func cost_text(cost: ManaCost) -> String:
		var out := "{%d}" % cost.generic if cost.generic > 0 else ""
		for c in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
			for n in int(cost.colored.get(c, 0)):
				out += "{%s}" % {Mtg.ManaColor.W: "W", Mtg.ManaColor.U: "U", Mtg.ManaColor.B: "B",
					Mtg.ManaColor.R: "R", Mtg.ManaColor.G: "G", Mtg.ManaColor.C: "C"}[c]
		return out if out != "" else "{0}"


# ================================================================ AI modes

static func _first_mode(_g: MtgGame, _pid: int) -> int: return 0

## Ivory Charm: shrink their attack while it is under way; otherwise tap
## their best untapped creature, or prevent if there is nothing to tap.
static func _ivory_mode(g: MtgGame, pid: int) -> int:
	if g.active_player != pid and not g.combat.attackers.is_empty(): return 0
	for i in g.players[g.opponent_of(pid)].creatures():
		if not i.tapped: return 1
	return 2

static func _chaos_charm_mode(g: MtgGame, pid: int) -> int:
	for i in g.players[g.opponent_of(pid)].creatures():
		if P.wall(i): return 0
	return 1

static func _reign_of_chaos_mode(g: MtgGame, pid: int) -> int:
	var plains := false
	var white := false
	for i in g.players[g.opponent_of(pid)].battlefield:
		plains = plains or P.plains(i)
		white = white or (i.is_creature() and P.white(i))
	return 0 if plains and white else 1

static func _seedling_mode(g: MtgGame, pid: int) -> int:
	for i in g.all_battlefield():
		if P.aura(i) and i.controller_id != pid and P.on_creature(g, i): return 0
	return 2


# ============================================================ white classes

## Afterlife: the creature's controller (last known, CR 608.2h) gets the
## Spirit whether or not the destruction happened (it is a separate
## instruction; an indestructible creature still yields one).
class Afterlife extends DestroyEffect:
	var spirit: CardData
	func _init() -> void:
		super(TargetSpec.creature(), false)
		spirit = CardData.new("Spirit", "", Mtg.CardType.CREATURE).pt(1, 1) \
			.with_colors(Mtg.ManaColor.W).with_subtypes(["spirit"]).with_keywords([Mtg.Keyword.FLYING])
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD: return
		var who := victim.controller_id
		g.destroy(victim, false)
		g.create_token(who, spirit)
	func describe() -> String:
		return "destroy target creature (it can't be regenerated); its controller creates a 1/1 white Spirit token with flying"


## "Put target <permanent> on top of its owner's library" (Disempower,
## Fallow Earth) — a ReturnToHandEffect in the AI's eyes, a library-top
## move through MtgGame in fact.
class ToLibraryTop extends ReturnToHandEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD: g.return_permanent_to_library_top(i)
	func describe() -> String:
		return "put %s on top of its owner's library" % target_spec.description


## Illumination: the countered spell's controller gains its mana value —
## read on the stack, where X counts (CR 202.3e), before the counter
## forgets it.
class Illumination extends CounterEffect:
	func _init() -> void:
		super("target artifact or enchantment spell", P.artifact_or_enchantment)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var spell := g.find_instance(t.instance_id)
		if spell == null or spell.zone != Mtg.Zone.STACK: return
		var item := g.find_stack_item(spell)
		var who := spell.controller_id if item == null else item.controller
		var value := spell.data.cost.mana_value() + g.casting_x(spell) * spell.data.cost.x_count
		g.counter_spell(spell)
		g.adjust_life(who, value)
	func describe() -> String:
		return "counter target artifact or enchantment spell; its controller gains life equal to its mana value"


static func _after_combat(g: MtgGame, _pid: int) -> String:
	return "" if g.current_step() in [Mtg.Step.MAIN2, Mtg.Step.END, Mtg.Step.CLEANUP] \
		else "Cast this spell only after combat"


class Influence extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature("target nonartifact, nonblack creature that attacked you this turn",
			P.nonartifact_nonblack).with_source_filter(P.attacked_you).because(TargetSpec.WHY["attacked"])
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		g.change_control(i, pid)
		g.add_counters(i, "-1/-0")
	func describe() -> String:
		return "gain control of target nonartifact, nonblack creature that attacked you this turn and put a -1/-0 counter on it"


## Mangara's Blessing's discard trigger: the card in the graveyard hears
## its own CARD_DISCARDED event (MtgGame._announce_discard). "Causes you to
## discard" by a spell or ability an OPPONENT controls — by_effect, with
## an effect controller other than the card's owner.
static func _hostile_discard(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var cause := int(e.data.get("effect_controller", -1))
	return e.data.get("instance") == s and bool(e.data.get("by_effect", false)) \
		and cause != -1 and cause != s.owner_id

static func _discard_context(_g: MtgGame, _s: CardInstance, e: GameEvent) -> Dictionary:
	var i: CardInstance = e.data.instance
	return {"id": i.id, "stamp": i.graveyard_entry, "in_grave": i.zone == Mtg.Zone.GRAVEYARD, "owner": i.owner_id}

static func _blessing_returns(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var who := int(ctx.get("owner", s.owner_id))
	g.adjust_life(who, 2)
	# "Return this card from your graveyard": the object that was discarded
	# into the graveyard, still there at the next end step (CR 400.7).
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _blessing_home,
		"Return Mangara's Blessing from your graveyard to your hand."), who, s, false,
		{"id": int(ctx.get("id", s.id)), "stamp": int(ctx.get("stamp", -1)),
			"in_grave": bool(ctx.get("in_grave", false))})

static func _blessing_home(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var i := g.find_instance(int(memory.get("id", -1)))
	if i != null and bool(memory.get("in_grave", false)) and i.zone == Mtg.Zone.GRAVEYARD \
			and i.graveyard_entry == int(memory.get("stamp", -1)):
		g.return_from_graveyard_to_hand(i)


# ============================================================= blue classes

static func _dream_cache(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var count := mini(2, g.players[pid].hand.size())
	if count == 0: return
	var places: Array[String] = ["Both on top of your library", "Both on the bottom of your library"]
	var where := g.agents[pid].choose_option(g, pid, places, "Dream Cache: where do the two cards go?", 1)
	for n in count:
		var hand: Array[CardInstance] = g.players[pid].hand.duplicate()
		var worst := P.best_first(g, hand)
		worst.reverse()
		var chosen := g.agents[pid].choose_card(g, pid, worst, "Dream Cache: choose a card to put %s" %
			("on top of your library" if where == 0 else "on the bottom of your library"))
		if chosen == null or not worst.has(chosen): chosen = worst[0]
		if where == 0: g.put_from_hand_on_top_of_library(chosen)
		else: g.put_on_bottom_of_library(chosen)


## Ether Well: "if that creature is red" is judged as it resolves; the
## bottom is reached through the top so the departure is a real one
## (leave triggers, auras, a token ceasing to exist).
class EtherWell extends ReturnToHandEffect:
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var bottom := P.color(i, Mtg.ManaColor.R) and g.agents[pid].choose_yes_no(g, pid,
			"Ether Well: put %s on the bottom of its owner's library instead?" % i.data.card_name,
			i.owner_id != pid)
		g.return_permanent_to_library_top(i)
		if bottom and i.zone == Mtg.Zone.LIBRARY: g.put_on_bottom_of_library(i)
	func describe() -> String:
		return "put target creature on top of its owner's library (a red one may go to the bottom instead)"


## Flash's payment: the creature's mana cost less {2} of its GENERIC part
## (CR 601.2f — a reduction never eats coloured pips); X is 0 off the stack.
static func _flash_cost(card: CardInstance) -> ManaCost:
	var cost := card.data.cost.minus_generic(2)
	cost.has_x = false
	cost.x_count = 0
	return cost

static func _flash(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var creatures: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_creature(): creatures.append(card)
	if creatures.is_empty(): return
	creatures.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var pay_a := g.can_afford_cost(pid, _flash_cost(a))
		var pay_b := g.can_afford_cost(pid, _flash_cost(b))
		if pay_a != pay_b: return pay_a
		return a.data.cost.mana_value() > b.data.cost.mana_value())
	if not g.agents[pid].choose_yes_no(g, pid, "Flash: put a creature card from your hand onto the battlefield?",
			g.can_afford_cost(pid, _flash_cost(creatures[0]))):
		return
	var chosen := g.agents[pid].choose_card(g, pid, creatures, "Flash: choose a creature card to put onto the battlefield")
	if chosen == null or not creatures.has(chosen): chosen = creatures[0]
	g.put_from_hand_into_play(chosen, pid)
	if chosen.zone != Mtg.Zone.BATTLEFIELD: return
	var stamp := chosen.layer_timestamp
	var cost := _flash_cost(chosen)
	if EffectBase.unless_paid(g, pid, cost, "Flash: pay %s to keep %s?" % [P.cost_text(cost), chosen.data.card_name]):
		return
	if chosen.zone == Mtg.Zone.BATTLEFIELD and chosen.layer_timestamp == stamp:
		g.sacrifice_permanent(chosen)


## Jolt's "you may tap or untap": three answers, the last one declining.
class TapOrUntap extends TapEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", P.artifact_creature_or_land))
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var labels: Array[String] = ["Tap it", "Untap it", "Leave it as it is"]
		var hint := 2
		if i.controller_id == pid and i.tapped: hint = 1
		elif i.controller_id != pid and not i.tapped: hint = 0
		match g.agents[pid].choose_option(g, pid, labels, "Jolt: tap or untap %s?" % i.data.card_name, hint):
			0: g.tap_permanent(i)
			1: g.untap_permanent(i)
	func describe() -> String:
		return "you may tap or untap target artifact, creature, or land"


static func _meddle(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var spell := g.find_instance(t.instance_id)
	if spell == null: return
	var item := g.find_stack_item(spell)
	# "If target spell has only one target and that target is a creature" —
	# checked as Meddle resolves; otherwise it does nothing.
	if item == null or item.kind != Mtg.StackKind.SPELL or item.targets.size() != 1: return
	var current: TargetRef = item.targets[0]
	if current.is_player: return
	var now := g.find_instance(current.instance_id)
	if now == null or now.zone != Mtg.Zone.BATTLEFIELD or not now.is_creature(): return
	var candidates: Array[TargetRef] = []
	for ref in g.single_spell_retargets(spell):
		if ref.is_player: continue
		var other := g.find_instance(ref.instance_id)
		if other != null and other.zone == Mtg.Zone.BATTLEFIELD and other.is_creature():
			candidates.append(ref)
	if candidates.is_empty(): return
	# Hint: a helpful spell (it pumps or protects) lands on our best
	# creature, a harmful one on theirs — public facts of the stack item.
	var helpful := false
	for effect in item.effects:
		if effect.target_spec != null:
			helpful = effect.ai_helpful or effect is PumpEffect or effect is RegenerateEffect \
				or effect is PreventDamageEffect
			break
	var labels: Array[String] = []
	var best := 0
	var top := -INF
	for n in candidates.size():
		var other := g.find_instance(candidates[n].instance_id)
		labels.append(other.data.card_name)
		var worth := float(maxi(1, other.data.cost.mana_value()) + maxi(0, other.cur_power) + maxi(0, other.cur_toughness))
		var score := worth if (other.controller_id == pid) == helpful else -worth
		if score > top:
			top = score
			best = n
	var at := g.agents[pid].choose_option(g, pid, labels, "Meddle: choose the spell's new target", best)
	g.retarget_spell(spell, 0, candidates[clampi(at, 0, candidates.size() - 1)])


## Mind Bend: Sleight of Mind and Magical Hack in one — a colour word OR a
## basic land type, over the words this engine models (protection colours,
## land subtypes, landwalk). The target is limited to permanents carrying
## such a word, as theirs are; see the Text changes row of
## docs/simplified-cards.md.
class MindBend extends EffectBase:
	const LANDS: Array[String] = ["plains", "island", "swamp", "mountain", "forest"]
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target permanent with a color word or basic land type in its text", MindBend.has_word)
	static func has_word(i: CardInstance) -> bool:
		if (i.cur_protection & 31) != 0: return true
		for t in LANDS:
			if i.has_subtype(t) or i.cur_landwalk.has(t): return true
		return false
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD: return
		var kinds: Array[String] = []
		var values: Array = []
		var labels: Array[String] = []
		for c in Mtg.WUBRG:
			if (victim.cur_protection & c) != 0:
				kinds.append("color_word")
				values.append(c)
				labels.append(String(Mtg.COLOR_NAMES[c]))
		for land in LANDS:
			if victim.has_subtype(land) or victim.cur_landwalk.has(land):
				kinds.append("land_type")
				values.append(land)
				labels.append(land.capitalize())
		if labels.is_empty(): return
		var pick := clampi(g.agents[pid].choose_option(g, pid, labels,
			"Mind Bend %s: which word?" % victim.data.card_name, 0), 0, labels.size() - 1)
		var others: Array = []
		var names: Array[String] = []
		if kinds[pick] == "color_word":
			for c in Mtg.WUBRG:
				if c != int(values[pick]):
					others.append(c)
					names.append(String(Mtg.COLOR_NAMES[c]))
		else:
			for land in LANDS:
				if land != String(values[pick]):
					others.append(land)
					names.append(land.capitalize())
		var to := clampi(g.agents[pid].choose_option(g, pid, names,
			"Mind Bend: %s becomes which word?" % labels[pick], 0), 0, names.size() - 1)
		g.change_text(victim, kinds[pick], values[pick], others[to])
	func describe() -> String:
		return "replace one color word or basic land type with another in target permanent's text"


class LandSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land you control", P.land) \
			.with_source_filter(P.yours).because(TargetSpec.WHY["controller"])
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass   # the slot is the effect; LandSwap trades
	func describe() -> String:
		return "the land you give away"


## Political Trickery's exchange. An illegal target on either side stops
## the whole exchange (CR 701.12b): the engine only re-judges THIS
## effect's own ref, so the land given away is re-judged here.
class LandSwap extends EffectBase:
	var give_spec: TargetSpec
	func _init(p_give: TargetSpec) -> void:
		give_spec = p_give
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land an opponent controls", P.land) \
			.with_source_filter(P.theirs).because(TargetSpec.WHY["controller"])
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var slots := g.current_targets()
		if slots.size() < 2 or t == null: return
		var mine_ref: TargetRef = slots[0]
		var mine := g.find_instance(mine_ref.instance_id)
		var theirs := g.find_instance(t.instance_id)
		if mine == null or theirs == null or not give_spec.is_legal(g, mine_ref, s): return
		g.exchange_control(mine, theirs)
	func describe() -> String:
		return "exchange control of target land you control and target land an opponent controls"


## Polymorph: the creature's controller (last known) reveals from the top
## until a creature card, puts it onto the battlefield, and shuffles the
## rest back — the reveal happens even if the destruction did not.
class Polymorph extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.creature(), false)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var victim := g.find_instance(t.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD: return
		var who := victim.controller_id
		g.destroy(victim, false)
		var library: Array = g.players[who].library
		var names: Array = []
		var found: CardInstance = null
		for n in range(library.size() - 1, -1, -1):
			var card: CardInstance = library[n]
			names.append(card.data.card_name)
			if card.data.is_creature():
				found = card
				break
		g.reveal_information(-1, "Polymorph — revealed cards", names)
		if found != null: g.put_library_card_onto_battlefield(found, who)
		g.shuffle_library(who)
	func describe() -> String:
		return "destroy target creature (no regeneration); its controller reveals until a creature card and puts it onto the battlefield"


class PrismaticLace extends ChangeColorEffect:
	func _init() -> void:
		super(0, TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var hint := P.enemy_main_color(g, pid)
		var chosen := g.agents[pid].choose_color(g, pid,
			"Prismatic Lace: choose the color or colors %s becomes" % i.data.card_name, hint) & 31
		g.set_color(i, chosen if chosen != 0 else hint)
	func describe() -> String:
		return "target permanent becomes the color or colors of your choice"


class PsychicTransfer extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var other := t.player_id
		var mine := g.players[pid].life
		var theirs := g.players[other].life
		if other == pid or absi(mine - theirs) > 5: return
		g.adjust_life(pid, theirs - mine)
		g.adjust_life(other, mine - theirs)
	func describe() -> String:
		return "exchange life totals with target player if they differ by 5 or less"


class TidalWave extends CreateTokenEffect:
	func _init() -> void:
		super("Wall", 5, 5, Mtg.ManaColor.U, "wall")
		token.with_keywords([Mtg.Keyword.DEFENDER])
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		for wall in g.create_token(pid, token, count):
			g.doom_at_next_end_step(wall, false, false, true)
	func describe() -> String:
		return "create a 5/5 blue Wall token with defender; sacrifice it at the beginning of the next end step"


# ============================================================ black classes

## Bone Harvest: any number of creature cards from your graveyard, put on
## top in the order the caster chooses (the first chosen ends on top).
class GraveToTop extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
			"any number of target creature cards from your graveyard")
		target_min = 0
		target_max = -1
		resolves_untargeted = true
		ai_helpful = true
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass
	func resolve_multi(g: MtgGame, _s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		var cards: Array[CardInstance] = []
		for ref in targets:
			var i := g.find_instance(ref.instance_id)
			if i != null and i.zone == Mtg.Zone.GRAVEYARD: cards.append(i)
		var ordered: Array[CardInstance] = []
		while not cards.is_empty():
			var ranked := P.best_first(g, cards)
			var chosen: CardInstance = ranked[0] if ranked.size() == 1 else g.agents[pid].choose_card(g, pid, ranked,
				"Bone Harvest: choose the next card from the top of your library")
			if chosen == null or not cards.has(chosen): chosen = ranked[0]
			ordered.append(chosen)
			cards.erase(chosen)
		ordered.reverse()
		for card in ordered: g.return_from_graveyard_to_library_top(card)
	func describe() -> String:
		return "put any number of target creature cards from your graveyard on top of your library"


class ChokingSands extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target non-Swamp land", P.non_swamp_land)
			.because(TargetSpec.WHY["subtype"]))
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var land := g.find_instance(t.instance_id)
		if land == null or land.zone != Mtg.Zone.BATTLEFIELD: return
		# "If that land was nonbasic" — its last known supertypes, and the
		# damage follows whether or not the land was destroyed.
		var who := land.controller_id
		var nonbasic := not P.basic(land)
		g.destroy(land)
		if nonbasic: g.deal_damage(s, TargetRef.player(who), 2)
	func describe() -> String:
		return "destroy target non-Swamp land; if it was nonbasic, deal 2 damage to its controller"


class GraveExile extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD,
			"up to three target cards from a single graveyard") \
			.with_sibling_filter(P.same_graveyard, TargetSpec.WHY["owner"])
		target_spec.compare_within_group = true
		target_min = 0
		target_max = 3
		resolves_untargeted = true
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		if t == null: return
		var i := g.find_instance(t.instance_id)
		if i != null and i.zone == Mtg.Zone.GRAVEYARD: g.exile_from_graveyard(i)
	func describe() -> String:
		return "exile up to three target cards from a single graveyard"


class HalfLife extends GainLifeEffect:
	func _init() -> void:
		super(0)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var life := g.players[pid].life
		if life > 0: g.adjust_life(pid, -ceili(life / 2.0))
	func describe() -> String:
		return "you lose half your life, rounded up"


## "N damage to each <main> creature and an additional 1 damage to each
## <extra> creature" (Kaervek's Hex, Tropical Storm): ONE damage event per
## creature carrying both amounts, all dealt simultaneously (CR 704.3).
class ColorSweep extends DamageAllEffect:
	var main: Callable
	var extra: Callable
	func _init(p_amount: int, p_desc: String, p_main: Callable, p_extra: Callable) -> void:
		super(p_amount, p_desc, ColorSweep.either.bind(p_main, p_extra))
		main = p_main
		extra = p_extra
	static func either(i: CardInstance, a: Callable, b: Callable) -> bool:
		return bool(a.call(i)) or bool(b.call(i))
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, x := 0) -> void:
		var base: int = x if use_x else amount
		var hits: Array = []
		for i in g.all_battlefield():
			if not i.is_creature(): continue
			var n: int = (base if bool(main.call(i)) else 0) + (1 if bool(extra.call(i)) else 0)
			if n > 0: hits.append([i, n])
		g.begin_simultaneous()
		for hit in hits: g.deal_damage(s, TargetRef.card(hit[0]), int(hit[1]))
		g.end_simultaneous()
	func describe() -> String:
		return "deals %s damage to %s" % ["X" if use_x else str(amount), description]


static func _painful_memories(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var victim := t.player_id
	var hand: Array[CardInstance] = g.players[victim].hand.duplicate()
	var names: Array = []
	for card in hand: names.append(card.data.card_name)
	# The look is the card's own permission (fair play): the caster sees
	# this hand, and the record says so.
	g.reveal_information(pid, "Painful Memories — %s's hand" % g.players[victim].player_name, names)
	if hand.is_empty(): return
	var ranked := P.best_first(g, hand)
	var chosen := g.agents[pid].choose_card(g, pid, ranked, "Painful Memories: choose a card to put on top of their library")
	if chosen == null or not ranked.has(chosen): chosen = ranked[0]
	g.put_from_hand_on_top_of_library(chosen)


class ReignOfTerror extends DestroyAllEffect:
	func _init() -> void:
		super("all green creatures or all white creatures", P.green_or_white_creature, false)
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var labels: Array[String] = ["Destroy all green creatures", "Destroy all white creatures"]
		var colors: Array[int] = [Mtg.ManaColor.G, Mtg.ManaColor.W]
		var worth: Array[float] = [0.0, 0.0]
		for i in g.all_battlefield():
			if not i.is_creature(): continue
			for n in 2:
				if P.color(i, colors[n]):
					worth[n] += (1.0 if i.controller_id != pid else -1.0) * (1.0 + float(maxi(0, i.cur_power)))
		var pick := clampi(g.agents[pid].choose_option(g, pid, labels, "Reign of Terror: which color?",
			0 if worth[0] >= worth[1] else 1), 0, 1)
		var victims: Array[CardInstance] = []
		var entries := {}
		for i in g.all_battlefield():
			if i.is_creature() and P.color(i, colors[pick]):
				victims.append(i)
				entries[i.id] = i.graveyard_entry
		g.begin_simultaneous()
		for i in victims: g.destroy(i, false)
		# "Each creature that died this way" — a creature that reached a
		# graveyard (a token too: it gets there before ceasing to exist).
		var died := 0
		for i in victims:
			if i.graveyard_entry != int(entries[i.id]): died += 1
		if died > 0: g.adjust_life(pid, -2 * died)
		g.end_simultaneous()
	func describe() -> String:
		return "destroy all green creatures or all white creatures (no regeneration); you lose 2 life for each that died"


static func _shallow_grave(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var grave: Array = g.players[pid].graveyard
	var top: CardInstance = null
	for n in range(grave.size() - 1, -1, -1):   # the graveyard's top is its back
		var card: CardInstance = grave[n]
		if card.data.is_creature():
			top = card
			break
	if top == null: return
	g.reanimate(top, pid)
	if top.zone != Mtg.Zone.BATTLEFIELD: return
	var haste: Array[int] = [Mtg.Keyword.HASTE]
	g.continuous.add_until_eot_pump(top.id, 0, 0, haste)
	g.recalculate()
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _exile_returned,
		"Exile the creature Shallow Grave returned."), pid, s, false,
		{"id": top.id, "stamp": top.layer_timestamp})

static func _exile_returned(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	var memory: Dictionary = g.current_delayed().get("memory", {})
	var i := g.find_instance(int(memory.get("id", -1)))
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == int(memory.get("stamp", -1)):
		g.exile_permanent(i)


class SoulRend extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.creature(), false)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i != null and i.zone == Mtg.Zone.BATTLEFIELD and P.white(i): g.destroy(i, false)
	func describe() -> String:
		return "destroy target creature if it's white (it can't be regenerated)"


class Soulshriek extends PumpEffect:
	func _init() -> void:
		super(0, 0)
		target_spec = TargetSpec.creature("target creature you control").with_source_filter(P.yours) \
			.because(TargetSpec.WHY["controller"])
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var x := 0
		for card in g.players[pid].graveyard:
			if card.data.is_creature(): x += 1
		g.continuous.add_until_eot_pump(i.id, x, 0)
		g.recalculate()
		g.doom_at_next_end_step(i, false, false, true)
	func describe() -> String:
		return "target creature you control gets +X/+0 (X = creature cards in your graveyard); sacrifice it at the next end step"


class Stupor extends RandomHandDiscardEffect:
	func _init() -> void:
		super(1)
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var who := t.player_id
		g.discard_random(who, 1)
		if g.players[who].hand.is_empty(): return
		g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))
	func describe() -> String:
		return "target opponent discards a card at random, then discards a card"


# ============================================================== red classes

## Builder's Bane: X target artifacts, then each player is dealt damage
## equal to the artifacts THEY controlled that reached a graveyard — one
## resolution, one bracket (CR 704.3).
class BuildersBane extends DestroyEffect:
	func _init() -> void:
		super(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", P.artifact))
		x_targets()
	func resolve_multi(g: MtgGame, s: CardInstance, _pid: int, targets: Array, _x := 0) -> void:
		var buried := {}
		g.begin_simultaneous()
		for ref in targets:
			var i := g.find_instance(ref.instance_id)
			if i == null or i.zone != Mtg.Zone.BATTLEFIELD: continue
			var who := i.controller_id
			var entry := i.graveyard_entry
			g.destroy(i)
			if i.graveyard_entry != entry: buried[who] = int(buried.get(who, 0)) + 1
		for who in [g.active_player, g.opponent_of(g.active_player)]:
			if int(buried.get(who, 0)) > 0: g.deal_damage(s, TargetRef.player(who), int(buried[who]))
		g.end_simultaneous()
	func describe() -> String:
		return "destroy X target artifacts; each player is dealt damage equal to the artifacts they controlled put into a graveyard this way"


## "Destroy target creature. If [a white] creature dies this way, deal
## damage equal to its power to its controller" (Cinder Cloud, Kaervek's
## Purge). Power, colour and controller are last known (CR 608.2h); "dies"
## means it reached a graveyard — regenerated or exiled instead, nothing.
class DeathBurn extends DestroyEffect:
	var white_only := false
	func _init(spec: TargetSpec, p_white_only: bool) -> void:
		super(spec)
		white_only = p_white_only
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null or i.zone != Mtg.Zone.BATTLEFIELD: return
		var who := i.controller_id
		var power := i.cur_power
		var white := P.white(i)
		var entry := i.graveyard_entry
		g.destroy(i)
		if i.graveyard_entry == entry or (white_only and not white): return
		if power > 0: g.deal_damage(s, TargetRef.player(who), power)
	func describe() -> String:
		return "destroy %s; if %s dies this way, deal damage equal to its power to its controller" % [
			target_spec.description, "a white creature" if white_only else "it"]


class FinalTurn extends ExtraTurnEffect:
	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.add_extra_turn(pid, s)
		g.log_line("%s will take an extra turn, then lose at its end step" % g.players[pid].player_name)
	func describe() -> String:
		return "take an extra turn after this one; at the beginning of that turn's end step, you lose the game"


static func _hammer_home(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	# The same graveyard object that paid the activation (CR 400.7).
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.cost_paid("_source_graveyard_entry", -1)):
		g.return_from_graveyard_to_hand(s)


static func _sirocco(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var who := t.player_id
	var hand: Array[CardInstance] = g.players[who].hand.duplicate()
	var names: Array = []
	for card in hand: names.append(card.data.card_name)
	g.reveal_information(-1, "Sirocco — %s's hand" % g.players[who].player_name, names)
	for card in hand:
		if card.zone != Mtg.Zone.HAND or not card.data.is_type(Mtg.CardType.INSTANT) \
				or (card.data.color_mask() & Mtg.ManaColor.U) == 0:
			continue
		# Paying life needs that much life (CR 119.4); the payer is the
		# player whose card it is.
		var life := g.players[who].life
		if life >= 4 and g.agents[who].choose_yes_no(g, who,
				"Sirocco: pay 4 life to keep %s?" % card.data.card_name, life > 8):
			g.adjust_life(who, -4)
			continue
		g.discard_cards(who, [card])


# ============================================================ green classes

static func _early_harvest(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	for i in g.players[t.player_id].battlefield.duplicate():
		if i.is_land() and P.basic(i) and i.tapped: g.untap_permanent(i)


static func _opponent_cast_creature(g: MtgGame, pid: int) -> String:
	for who in g.players.size():
		if who == pid: continue
		for data in g.spells_cast_this_turn[who]:
			if data.is_creature(): return ""
	return "Cast this spell only if an opponent cast a creature spell this turn"

static func _lure_of_prey(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var green: Array[CardInstance] = []
	for card in g.players[pid].hand:
		if card.data.is_creature() and (card.data.color_mask() & Mtg.ManaColor.G) != 0: green.append(card)
	if green.is_empty(): return
	var ranked := P.best_first(g, green)
	var chosen := g.agents[pid].choose_card(g, pid, ranked,
		"Lure of Prey: you may put a green creature card onto the battlefield", true)
	if chosen == null or not ranked.has(chosen): return
	g.put_from_hand_into_play(chosen, pid)


class SeedsOfInnocence extends DestroyAllEffect:
	func _init() -> void:
		super("all artifacts", P.artifact, false)
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var victims: Array[CardInstance] = []
		for i in g.all_battlefield():
			if P.artifact(i): victims.append(i)
		var owner := {}
		var value := {}
		var entry := {}
		for i in victims:
			owner[i.id] = i.controller_id
			value[i.id] = i.data.cost.mana_value()
			entry[i.id] = i.graveyard_entry
		g.begin_simultaneous()
		for i in victims: g.destroy(i, false)
		# "The controller of each of those artifacts" — the ones destroyed,
		# by their last known controller.
		var gains := {}
		for i in victims:
			if i.graveyard_entry != int(entry[i.id]):
				gains[owner[i.id]] = int(gains.get(owner[i.id], 0)) + int(value[i.id])
		for who in [g.active_player, g.opponent_of(g.active_player)]:
			if int(gains.get(who, 0)) > 0: g.adjust_life(who, int(gains[who]))
		g.end_simultaneous()
	func describe() -> String:
		return "destroy all artifacts (no regeneration); each controller gains life equal to their mana values"


## Superior Numbers: the damage reads the OTHER slot (the target opponent)
## through MtgGame.current_targets, as Gauntlets of Chaos does.
class Numbers extends DamageEffect:
	func _init() -> void:
		super(0)
		target_spec = TargetSpec.creature()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var slots := g.current_targets()
		if slots.size() < 2 or t == null: return
		var foe: TargetRef = slots[1]
		if not foe.is_player: return
		var surplus := g.players[pid].creatures().size() - g.players[foe.player_id].creatures().size()
		if surplus > 0: g.deal_damage(s, t, surplus)
	func describe() -> String:
		return "deal damage to target creature equal to how many more creatures you control than target opponent"


class OpponentSlot extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()
	func resolve(_g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		pass   # counted by Numbers
	func describe() -> String:
		return "the opponent whose creatures are counted"


class WeedCats extends CreateTokenEffect:
	func _init() -> void:
		super("Cat", 1, 1, Mtg.ManaColor.G, "cat")
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		var counts := {}
		for p in g.players:
			var n := 0
			for i in p.battlefield:
				if i.is_land() and i.has_subtype("forest") and not i.tapped: n += 1
			counts[p.id] = n
		for who in [g.active_player, g.opponent_of(g.active_player)]:
			if int(counts.get(who, 0)) > 0: g.create_token(who, token, int(counts[who]))
	func describe() -> String:
		return "each player creates a 1/1 green Cat token for each untapped Forest they control"


# ============================================================= gold classes

class PrismaticBoon extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.creature()
		x_targets()
		ai_helpful = true
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		resolve_multi(g, s, pid, [] if t == null else [t], x)
	func resolve_multi(g: MtgGame, _s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		var alive: Array[CardInstance] = []
		for ref in targets:
			var i := g.find_instance(ref.instance_id)
			if i != null and i.zone == Mtg.Zone.BATTLEFIELD: alive.append(i)
		if alive.is_empty(): return
		var hint := P.enemy_main_color(g, pid)
		var chosen := g.agents[pid].choose_color(g, pid, "Prismatic Boon: choose a color", hint) & 31
		var color := hint
		for c in Mtg.WUBRG:   # "a color": exactly one
			if (chosen & c) != 0:
				color = c
				break
		for i in alive: g.continuous.add_until_eot_protection(i.id, color)
		g.recalculate()
	func describe() -> String:
		return "X target creatures gain protection from the color of your choice until end of turn"


static func _sealed_fate(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, x: int) -> void:
	var who := t.player_id
	var library: Array = g.players[who].library
	var n := mini(x, library.size())
	if n <= 0: return
	var seen: Array[CardInstance] = []
	for k in n: seen.append(library[library.size() - 1 - k])
	var names: Array = []
	for card in seen: names.append(card.data.card_name)
	g.reveal_information(pid, "Sealed Fate — the top %d card(s) of %s's library" % [n, g.players[who].player_name], names)
	var ranked := P.best_first(g, seen)
	var chosen := g.agents[pid].choose_card(g, pid, ranked, "Sealed Fate: choose a card to exile")
	if chosen == null or not ranked.has(chosen): chosen = ranked[0]
	g.exile_library_card(chosen)
	seen.erase(chosen)
	# "...the rest back on top of that player's library in any order": the
	# caster orders them, the first chosen ending on top.
	var ordered: Array[CardInstance] = []
	while seen.size() > 1:
		var worst := P.best_first(g, seen)
		worst.reverse()
		var next := g.agents[pid].choose_card(g, pid, worst, "Sealed Fate: choose the next card from the top")
		if next == null or not worst.has(next): next = worst[0]
		ordered.append(next)
		seen.erase(next)
	ordered.append_array(seen)
	g.reorder_top_of_library(who, ordered)


class Cascade extends GainLifeEffect:
	func _init() -> void:
		super(3)
		use_x = true
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, x := 0) -> void:
		g.adjust_life(pid, x + 3)
	func describe() -> String:
		return "you gain X plus 3 life"
