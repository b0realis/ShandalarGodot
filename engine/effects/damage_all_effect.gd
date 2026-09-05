class_name DamageAllEffect
extends EffectBase
## Sweeper damage: "[Source] deals N (or X) damage to each [filtered]
## creature [and each player]." — Earthquake, Pestilence-style effects.
##
## Untargeted, like all "each" effects — so protection only matters for the
## damage-prevention leg (the D of DEBT), which MtgGame.deal_damage applies.

## Damage dealt to each victim. Ignored when [member use_x] is set.
var amount: int

## When true the amount is the spell's X (Earthquake, Hurricane).
var use_x: bool = false

## When true each player takes the same damage as well (Earthquake hits
## players; Inferno hits "each creature and each player"; Pestilence does
## not stop at creatures either).
var hit_players: bool = false

## Which creatures are hit. Unset = every creature.
var creature_filter: Callable = Callable()

## Card-English scope for logs ("each creature without flying").
var description: String = "each creature"


func _init(p_amount: int, p_description: String = "each creature",
		p_filter: Callable = Callable()) -> void:
	amount = p_amount
	description = p_description
	creature_filter = p_filter


## Fluent: the damage is X.
func x_damage() -> DamageAllEffect:
	use_x = true
	return self


## Fluent: also hit each player.
func and_each_player() -> DamageAllEffect:
	hit_players = true
	return self


## Marks damage on every matching creature (and optionally every player)
## through MtgGame.deal_damage, which is where prevention, protection,
## redirection and the lethal-damage state-based action all live. Zero or
## negative damage is not an event at all (CR 120.8), hence the early out.
func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef,
		x_value: int = 0) -> void:
	var n := x_value if use_x else amount
	if n <= 0:
		return
	# Snapshot victims before dealing any damage: "each" effects hit
	# everything that matched at resolution start, simultaneously in spirit.
	var victims: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if not inst.is_creature():
			continue
		if creature_filter.is_valid() and not creature_filter.call(inst):
			continue
		victims.append(inst)
	# CR 704.3 + 704.4: a sweeper is ONE event. Nothing is swept off the
	# board until every packet has landed, so the creatures die together and
	# — the case this bracket exists for — an Earthquake that is lethal to
	# both duelists kills them SIMULTANEOUSLY, which is a draw (CR 104.4b)
	# and not a win for whichever seat the loop reached second.
	game.begin_simultaneous()
	for inst in victims:
		game.deal_damage(source, TargetRef.card(inst), n)
	if hit_players:
		for p in game.players:
			if not p.has_lost:
				game.deal_damage(source, TargetRef.player(p.id), n)
	game.end_simultaneous()


## One-line log/UI text.
func describe() -> String:
	var n := "X" if use_x else str(amount)
	var text := "deals %s damage to %s" % [n, description]
	if hit_players:
		text += " and each player"
	return text
