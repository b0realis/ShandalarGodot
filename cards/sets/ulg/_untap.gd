extends RefCounted
## Urza's Legacy (_untap, Pack 10). Spells and abilities that untap lands or
## permanents. The shared pieces — "untap up to N lands" (UntapUpToEffect,
## enters_untapping) and "untap this" (untap_self_ability) — are Urza's
## Saga's (cards/sets/usg/_untap.gd, whose header documents them).
##
## - Burst of Energy: UntapEffect on any permanent.
## - Hope and Glory: ONE effect taking exactly two different creatures
##   ("two target", Ashes to Ashes' shape, CR 601.2c); each target still
##   legal on resolution is untapped and gets +1/+1 (CR 608.2b).
## - Frantic Search: Emmessi Tome's draw-then-discard (the discards are an
##   effect's, chosen by the caster) with two each, then up to three lands.
## - Palinchron: up to seven lands as it enters; "{2}{U}{U}: Return this
##   creature to its owner's hand" only for the object whose ability it is
##   (role `self_bounce`). With High Tide (Pack 2) this is the classic
##   infinite-mana loop; MtgGame.LOOP_LIMIT ends a runaway one.
## - Snap: Unsummon then up to two lands; with its creature gone it does
##   nothing at all (CR 608.2b).
## - Grim Monolith: Basalt Monolith's shape at {4}; its lock works while it
##   is tapped under the 1997 tapped-artifact rule as well.
##
## tests/cards/test_pack_10_B9_untap_up_to.gd, test_pack_10_B9_untap.gd and
## test_pack_10_B9_loops.gd pin each card.
const F := preload("res://cards/sets/fem/_rules.gd")
const U := preload("res://cards/sets/usg/_untap.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Burst of Energy":
			c.spell(UntapEffect.new())
		"Hope and Glory":
			c.spell(HopeAndGlory.new())
		"Frantic Search":
			c.spell(FranticSearch.new())
			c.spell(U.UntapUpToEffect.new(3))
		"Palinchron":
			c.triggered(U.enters_untapping(7, "When this creature enters, untap up to seven lands."))
			c.activated(ActivatedAbility.new("{2}{U}{U}", false,
				[F.Action.new(_return_self, "return this creature to its owner's hand", null, true).with_ai_role(&"self_bounce")],
				"{2}{U}{U}: Return this creature to its owner's hand."))
		"Snap":
			c.spell(ReturnToHandEffect.new(TargetSpec.creature()))
			c.spell(U.UntapUpToEffect.new(2))
		"Vigilant Drake":
			c.activated(U.untap_self_ability("{2}{U}", "{2}{U}: Untap this creature."))
		"Grim Monolith":
			c.static_ability(StaticAbility.new(U._skips_untap,
				"This artifact doesn't untap during your untap step.").working_while_tapped())
			c.mana(ManaAbility.new(Mtg.ManaColor.C, 3))
			c.activated(U.untap_self_ability("{4}", "{4}: Untap this artifact.", "artifact"))
		_: return false
	return true


## "Return this creature to its owner's hand" — the very object (CR 400.7).
static func _return_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if F._same_activation_source(g, s):
		g.return_to_hand(s)


## "Untap two target creatures. Each of them gets +1/+1 until end of turn."
class HopeAndGlory extends UntapEffect:
	func _init() -> void:
		super(TargetSpec.creature())
		target_min = 2
		target_max = 2
		ai_helpful = true

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		var inst := g.find_instance(t.instance_id)
		if not g.is_present(inst):
			return
		super(g, s, pid, t, x)
		g.continuous.add_until_eot_pump(inst.id, 1, 1)
		g.recalculate()

	func describe() -> String:
		return "untap two target creatures; each gets +1/+1 until end of turn"


## "Draw two cards, then discard two cards." (the untap is its own effect).
class FranticSearch extends DrawEffect:
	func _init() -> void:
		super(2)

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var hand := g.players[pid].hand
		if hand.is_empty():
			return
		var thrown := g.agents[pid].choose_discard(g, pid, mini(2, hand.size()))
		if thrown.is_empty():
			thrown = hand.slice(maxi(0, hand.size() - 2))
		g.discard_cards(pid, thrown)

	func describe() -> String:
		return "draw two cards, then discard two cards"
