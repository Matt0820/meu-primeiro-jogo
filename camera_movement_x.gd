extends Camera3D

# Camera do jogador: o giro horizontal fica no corpo e o vertical nesta camera.
# Edite a constante abaixo para ajustar a sensibilidade vertical do mouse.

#cria as constantes de câmera
#sensibiliade
const sensibility = 0.003
#reverencia a camera


# Called when the node enters the scene tree for the first time.
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_x(event.relative.y * (-sensibility))
