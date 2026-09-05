class_name ManaCost
extends RefCounted
## An immutable, parsed mana cost such as [code]{2}{W}{W}[/code].
##
## Costs are written in card files using standard oracle brace notation and
## parsed once at registration time. Supported symbols in v0.1:
##   {W} {U} {B} {R} {G}  — colored requirements
##   {C}                  — a cost that only colorless mana can pay (rare)
##   {0}..{99}            — generic mana (any type can pay)
##   {X}                  — an X cost; the chosen value is supplied at cast
##                          time (MtgGame.cast_spell's x_value argument)
## Hybrid / Phyrexian / snow symbols are out of scope for the 1997 card pool;
## see docs/ROADMAP.md before adding them.

## Colored requirement counts, keyed by Mtg.Color flag. Never mutated after
## parse.
var colored: Dictionary = {}

## Generic portion of the cost (the number in {2} etc.). Payable by any mana.
var generic: int = 0

## Whether the cost contains {X}.
var has_x: bool = false

## How many {X} symbols the cost carries. Almost always 1, but Legends
## prints doubled costs ({X}{X}{U} — Part Water), where choosing X = 2 means
## paying four generic mana. Callers multiply their chosen X by this.
var x_count: int = 0

## The original text form, kept for logs, UI, and error messages.
var text: String = ""


## Parse [param cost_text] ("{1}{G}" etc.). An empty string is a free cost
## (used by lands, which are played, not cast). Unknown symbols push an
## error so a typo in a card file fails loudly at registration, not at cast.
static func parse(cost_text: String) -> ManaCost:
	var cost := ManaCost.new()
	cost.text = cost_text
	var regex := RegEx.new()
	regex.compile("\\{([^}]+)\\}")
	for m in regex.search_all(cost_text):
		var sym: String = m.get_string(1)
		match sym:
			"W": cost._add_colored(Mtg.ManaColor.W)
			"U": cost._add_colored(Mtg.ManaColor.U)
			"B": cost._add_colored(Mtg.ManaColor.B)
			"R": cost._add_colored(Mtg.ManaColor.R)
			"G": cost._add_colored(Mtg.ManaColor.G)
			"C": cost._add_colored(Mtg.ManaColor.C)
			"X":
				cost.has_x = true
				cost.x_count += 1
			_:
				if sym.is_valid_int():
					cost.generic += sym.to_int()
				else:
					push_error("ManaCost: unknown symbol {%s} in '%s'" % [sym, cost_text])
	return cost


func _add_colored(color: int) -> void:
	colored[color] = int(colored.get(color, 0)) + 1


## A COPY of this cost with [param n] less GENERIC mana (floored at zero).
## Coloured pips are never touched — a cost reduction can't eat them
## (CR 601.2f). Power Artifact's {2} discount uses it.
func minus_generic(n: int) -> ManaCost:
	var out := ManaCost.new()
	out.generic = maxi(generic - n, 0)
	out.has_x = has_x
	out.x_count = x_count
	out.text = text
	for c in colored:
		out.colored[c] = colored[c]
	return out


## A COPY of this cost with [param n] extra pips of [param color]
## ("Pay {R} for each target" — Goblin Polka Band's per-target payment).
## The copy drops {X}, because the count it stood for is now spelled out.
func plus_colored(color: int, n: int) -> ManaCost:
	var out := ManaCost.new()
	out.generic = generic
	out.text = text
	for c in colored:
		out.colored[c] = colored[c]
	if n > 0:
		out.colored[color] = int(out.colored.get(color, 0)) + n
	return out


## Mana value ("converted mana cost"). X counts as 0 while unresolved,
## per CR 203.3b.
func mana_value() -> int:
	var total := generic
	for c in colored:
		total += colored[c]
	return total


## Memoised [method color_mask] result (-1 = not computed yet). A cost is
## immutable after parsing, so the mask can be computed once — and it is
## read for every permanent on every recalculation, which makes it one of
## the engine's hottest reads.
var _color_mask: int = -1

## Bitmask of this cost's colors — defines the card's color per CR 105.2.
func color_mask() -> int:
	if _color_mask < 0:
		_color_mask = 0
		for c in colored:
			if c != Mtg.ManaColor.C:
				_color_mask |= c
	return _color_mask


func _to_string() -> String:
	return text if text != "" else "{0}"
