extends RefCounted
## Urza's Saga (_cycling, Pack 10). Cycling cards and "when you cycle" cards.
##
## CYCLING (CR 702.29a) is [method CardData.with_cycling] (Pack 10 engine
## package E2): an activated ability that functions only from its owner's
## HAND — "{2}, Discard this card: Draw a card." It is appended AFTER every
## printed battlefield ability (a Rune's {W} shield stays index 0), uses the
## stack, is activated any time its owner could cast an instant, and the
## discard is a COST discard (Megrim hears it; Library of Leng and Psychic
## Purge do not). A cycling land is played as the turn's land or cycled —
## never both, and cycling spends no land drop; on the battlefield it has
## no cycling to activate. The duel screen asks "Cast/Play" or "Cycling {2}"
## on the hand card's click.
##
## The rest of each card is the shape its printed text already has in the
## pool: Clear = Disenchant's enchantment half, Expunge = Terror, Lay Waste =
## Stone Rain, Scrap = Shatter, Hush = Tranquility, Lull = Fog, Rescind = a
## permanent bounce, the seven Runes of Protection = the Circles of
## Protection's shield for {W} (Artifacts/Lands read the source's live
## type), Lingering Mirage = Evil Presence with "Island", Sicken = a -1/-1
## Aura, Drifting Djinn = the Fallen Empires upkeep "sacrifice unless you
## pay". The Disciples, Shimmering Barrier, Pendrell Drake and the Sandbar
## pair print only keywords (their scaffolds) and cycling.
##
## - Fluctuator: "Cycling abilities you activate cost {2} less to activate"
##   is [method CardData.with_ability_cost_reduction] reading the ability's
##   cycling marker and the ACTIVATOR (its controller only): generic mana
##   only, floored at 0 (two Fluctuators make cycling {0}, never less), and
##   under the 1997 rule a tapped Fluctuator stops. Heartstone never touches
##   cycling: a creature card in a hand is no creature (CR 109.2).
## - Power Taint: the upkeep is the ENCHANTED ENCHANTMENT's controller's
##   (Wanderlust's shape with an enchantment host). "That player loses 2
##   life unless they pay {2}" is asked of that player as it resolves; it
##   resolves even if the Aura has left by then (CR 603.6). An Opal
##   enchantment that became a creature is still an enchantment while its
##   type line keeps the word.
## - Wild Dogs: "if a player has more life than each other player" is an
##   intervening if (CR 603.4) — two players: the life totals differ — read
##   as the upkeep begins and again as the trigger resolves, when the player
##   with the most life gains control of this very object (no change when
##   it already controls it). A permanent effect (ControlLayers, timestamp).
## - Brand: every permanent its caster OWNS comes back under their control,
##   each as an indefinite control effect newer than whatever took it (a
##   Control Magic's Aura stays on the creature and loses by timestamp).
##   Phased-out permanents do not change control (CR 702.26d).
##
## tests/cards/test_pack_10_B11_cycling.gd (every card's cycling, table-
## driven), test_pack_10_B11_usg.gd (each card's own text) and
## test_pack_10_B11_fluctuator.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")

const RUNE_COLORS := {
	"Rune of Protection: Black": ["black", Mtg.ManaColor.B],
	"Rune of Protection: Blue": ["blue", Mtg.ManaColor.U],
	"Rune of Protection: Green": ["green", Mtg.ManaColor.G],
	"Rune of Protection: Red": ["red", Mtg.ManaColor.R],
	"Rune of Protection: White": ["white", Mtg.ManaColor.W],
}

const CYCLING_LANDS := {
	"Drifting Meadow": Mtg.ManaColor.W,
	"Polluted Mire": Mtg.ManaColor.B,
	"Remote Isle": Mtg.ManaColor.U,
	"Slippery Karst": Mtg.ManaColor.G,
	"Smoldering Crater": Mtg.ManaColor.R,
}


static func configure(c: CardData) -> bool:
	match c.card_name:
		# ------------------------------------------------------------ white
		"Clear":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target enchantment", _is_enchantment)))
		"Disciple of Grace", "Disciple of Law", "Shimmering Barrier":
			pass   # protection / defender and first strike: the scaffold's
		"Rune of Protection: Artifacts":
			c.activated(_rune(PreventDamageShieldEffect.new(0) \
				.from_sources("an artifact source", _is_artifact), "an artifact source"))
		"Rune of Protection: Lands":
			c.activated(_rune(PreventDamageShieldEffect.new(0) \
				.from_sources("a land source", _is_land), "a land source"))
		"Rune of Protection: Black", "Rune of Protection: Blue", "Rune of Protection: Green", "Rune of Protection: Red", "Rune of Protection: White":
			var row: Array = RUNE_COLORS[c.card_name]
			c.activated(_rune(PreventDamageShieldEffect.new(int(row[1])),
				"a %s source" % String(row[0])))
		# ------------------------------------------------------------- blue
		"Drifting Djinn":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._upkeep_payment.bind("{1}{U}"),
				"At the beginning of your upkeep, sacrifice this creature unless you pay {1}{U}.", F._your_upkeep))
		"Lingering Mirage":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land))
			c.static_ability(StaticAbility.new(_island, "Enchanted land is an Island.") \
				.changing_land_types())
		"Pendrell Drake", "Sandbar Merfolk", "Sandbar Serpent":
			pass   # flying, or nothing but its body: the scaffold's
		"Power Taint":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _is_enchantment))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _taint,
				"At the beginning of the upkeep of enchanted enchantment's controller, that player loses 2 life unless they pay {2}.",
				_taint_upkeep))
		"Rescind":
			c.spell(ReturnToHandEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT)))
		# ------------------------------------------------------------ black
		"Expunge":
			c.spell(DestroyEffect.new(TargetSpec.creature(
				"target nonartifact, nonblack creature", _nonartifact_nonblack), false))
		"Sicken":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(F._aura_pump.bind(-1, -1), "Enchanted creature gets -1/-1."))
		# -------------------------------------------------------------- red
		"Brand":
			c.spell(F.Action.new(_brand, "gain control of all permanents you own", null, true) \
				.with_ai_role(&"regain_control"))
		"Lay Waste":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)))
		"Scrap":
			c.spell(DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
				"target artifact", _is_artifact)))
		# ------------------------------------------------------------ green
		"Hush":
			c.spell(DestroyAllEffect.new("all enchantments", _is_enchantment))
		"Lull":
			c.spell(PreventCombatDamageEffect.new())
		"Rejuvenate":
			c.spell(GainLifeEffect.new(6))
		"Wild Dogs":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _wild_dogs,
				"At the beginning of your upkeep, if a player has more life than each other player, the player with the most life gains control of this creature.",
				_wild_dogs_upkeep))
		# --------------------------------------------------------- artifact
		"Fluctuator":
			c.with_ability_cost_reduction(2, _cycling_you_activate, 0)
			return true   # no cycling of its own
		# ------------------------------------------------------------ lands
		"Blasted Landscape":
			c.mana(ManaAbility.new(Mtg.ManaColor.C))
		"Drifting Meadow", "Polluted Mire", "Remote Isle", "Slippery Karst", "Smoldering Crater":
			c.with_enters_tapped()
			c.mana(ManaAbility.new(int(CYCLING_LANDS[c.card_name])))
		_: return false
	c.with_cycling()
	return true


# --------------------------------------------------------------- predicates --

static func _is_enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func _is_artifact(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ARTIFACT)
static func _is_land(i: CardInstance) -> bool: return i.is_land()
static func _nonartifact_nonblack(i: CardInstance) -> bool:
	return not i.is_type(Mtg.CardType.ARTIFACT) and (i.cur_colors & Mtg.ManaColor.B) == 0


# ---------------------------------------------------------------- the Runes --

## "{W}: The next time <a source> of your choice would deal damage to you
## this turn, prevent that damage." — the Circles' shield, for {W}.
static func _rune(shield: PreventDamageShieldEffect, source_words: String) -> ActivatedAbility:
	return ActivatedAbility.new("{W}", false, [shield],
		"{W}: The next time %s of your choice would deal damage to you this turn, prevent that damage." % source_words)


# ---------------------------------------------------------- Lingering Mirage --

static func _island(g: MtgGame, s: CardInstance) -> void:
	if s.attached_to == -1:
		return
	var host := g.find_instance(s.attached_to)
	if g.is_present(host):
		host.become_basic_land_type("island", Mtg.ManaColor.U)


# -------------------------------------------------------------- Power Taint --

static func _taint_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if s.attached_to == -1:
		return false
	var host := g.find_instance(s.attached_to)
	return g.is_present(host) and host.controller_id == int(e.data.get("player", -1))


static func _taint(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("player", -1))
	if pid < 0:
		return
	if not EffectBase.unless_paid(g, pid, ManaCost.parse("{2}"),
			"Power Taint: pay {2}, or lose 2 life?"):
		g.adjust_life(pid, -2)


# -------------------------------------------------------------------- Brand --

static func _brand(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.owner_id == pid and i.controller_id != pid and g.is_present(i):
			g.change_control(i, pid)


# ---------------------------------------------------------------- Wild Dogs --

## The player with more life than each other player, or -1 (a tie).
static func most_life(g: MtgGame) -> int:
	var best := -1
	var tied := false
	for pid in g.players.size():
		if best < 0 or g.players[pid].life > g.players[best].life:
			best = pid
			tied = false
		elif g.players[pid].life == g.players[best].life:
			tied = true
	return -1 if tied else best


static func _wild_dogs_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return F._your_upkeep(g, s, e) and most_life(g) >= 0


static func _wild_dogs(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var leader := most_life(g)   # the intervening if, again (CR 603.4)
	if leader >= 0 and F._same_trigger_source(g, s) and s.controller_id != leader:
		g.change_control(s, leader)


# --------------------------------------------------------------- Fluctuator --

## "Cycling abilities YOU activate": the cycling marker, and the activator
## is the Fluctuator's controller.
static func _cycling_you_activate(_g: MtgGame, pid: int, _source: CardInstance,
		ability: ActivatedAbility, modifier: CardInstance) -> bool:
	return ability.is_cycling and pid == modifier.controller_id
