class_name GameEvent
extends RefCounted
## A thing that happened in the game — the currency of the trigger system.
##
## MtgGame.dispatch_event builds one of these for every noteworthy state
## change (see Mtg.EventType for the catalogue and each event's data keys)
## and offers it to every triggered ability on the battlefield. The UI layer
## receives the same events through MtgGame's [signal MtgGame.event_occurred]
## so animations can mirror exactly what the rules saw.

## One of Mtg.EventType.
var type: int

## Event payload. Keys per event type are documented on Mtg.EventType.
## Values are ints (player ids) or CardInstance references.
var data: Dictionary


func _init(p_type: int, p_data: Dictionary = {}) -> void:
	type = p_type
	data = p_data


func _to_string() -> String:
	return "%s %s" % [Mtg.EventType.keys()[type], data]
