extends AnimationTree

var playback : AnimationNodeStateMachinePlayback

const IDLES = 4

func _ready():
	active = true
	playback = get("parameters/playback")
	playback.start("sit_idle_" + str(idle))
	change_idle()

#-----------------------------------------------------------------------------#

# IDLE ANIMATION #

var idle = 0

func set_idle(index):
	idle = index
	playback.start("sit_idle_" + str(idle))
	change_idle()

func change_idle():
	idle = (idle + 1) % IDLES
	playback.travel("sit_idle_" + str(idle))

#-----------------------------------------------------------------------------#

# HAND-RAISING #

var is_raised = false

func raise_hand():
	if not is_raised:
		playback.travel("sit_raise_hand")
		is_raised = true

func lower_hand():
	if is_raised:
		playback.travel("sit_idle_" + str(idle))
		is_raised = false
