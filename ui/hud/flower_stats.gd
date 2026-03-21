extends HBoxContainer
class_name FlowerStats

# References to the count labels and meters
@onready var red_count: Label = $RedFlower/Count
@onready var red_meter: ProgressBar = $RedFlower/Meter
@onready var green_count: Label = $GreenFlower/Count
@onready var green_meter: ProgressBar = $GreenFlower/Meter
@onready var blue_count: Label = $BlueFlower/Count
@onready var blue_meter: ProgressBar = $BlueFlower/Meter

@export var max_flower_display: int = 99

func _ready() -> void:
	# Set up progress bar ranges
	for meter in [red_meter, green_meter, blue_meter]:
		if meter:
			meter.min_value = 0
			meter.max_value = max_flower_display
	
	_update_display()
	FlowerManager.flowers_changed.connect(func(_g, _b, _r): _update_display())

func _update_display() -> void:
	var red = FlowerManager.red_flowers
	var green = FlowerManager.green_flowers
	var blue = FlowerManager.blue_flowers
	
	if red_count:
		red_count.text = "%02d" % red
	if red_meter:
		red_meter.value = red
	
	if green_count:
		green_count.text = "%02d" % green
	if green_meter:
		green_meter.value = green
	
	if blue_count:
		blue_count.text = "%02d" % blue
	if blue_meter:
		blue_meter.value = blue
