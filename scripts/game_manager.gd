extends Node
## Global run state: state machine, run timer, kills, recent kill history.
## pocv5: every KILLS_PER_QUIZ kills triggers a 4-choice quiz. After a correct
## answer the bullet system rotates to a new pair of Japanese words.

enum State { PLAYING, QUIZ, GAMEOVER, RESULT }

const KILLS_PER_QUIZ: int = 10
const RECENT_KILLS_CAP: int = 32

var state: int = State.PLAYING
var run_time: float = 0.0
var kills: int = 0
var kills_since_quiz: int = 0
var recent_kills: Array = []  # Array[Dictionary] — most recent last

signal run_time_updated(t: float)
signal state_changed(s: int)
signal kills_changed(total: int, since_quiz: int)
signal quiz_threshold_reached(word: Dictionary)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		run_time += delta
		run_time_updated.emit(run_time)

func start_run() -> void:
	run_time = 0.0
	kills = 0
	kills_since_quiz = 0
	recent_kills.clear()
	set_state(State.PLAYING)

func set_state(s: int) -> void:
	state = s
	state_changed.emit(s)

func register_kill(word: Dictionary = {}) -> void:
	kills += 1
	kills_since_quiz += 1
	if not word.is_empty():
		recent_kills.append(word)
		if recent_kills.size() > RECENT_KILLS_CAP:
			recent_kills.pop_front()
	kills_changed.emit(kills, kills_since_quiz)
	if kills_since_quiz >= KILLS_PER_QUIZ:
		kills_since_quiz = 0
		var quiz_word: Dictionary = _pick_quiz_word()
		if not quiz_word.is_empty():
			quiz_threshold_reached.emit(quiz_word)

func _pick_quiz_word() -> Dictionary:
	if not recent_kills.is_empty():
		return recent_kills[randi() % recent_kills.size()]
	return WordDatabase.get_random_word()

func trigger_game_over() -> void:
	set_state(State.GAMEOVER)

func format_time(t: float) -> String:
	var clamped: float = max(0.0, t)
	var m: int = int(clamped) / 60
	var s: int = int(clamped) % 60
	return "%02d:%02d" % [m, s]
