extends CharacterBody3D

# Variante legada resistente. As hordas atuais usam zombie.gd.
# Mantido para preservar referências de cenas antigas do projeto.

const SPEED = 5.0# Mais lento que o player para dar tempo de fugir
const ALTURA_ACERTO_CABECA := 2.9
const ALTURA_ACERTO_PERNA := 1.15
const MULTIPLICADOR_DANO_CABECA := 2.0
const MULTIPLICADOR_LENTIDAO := 0.45
const DURACAO_LENTIDAO := 2.5
@onready var player = get_tree().get_first_node_in_group("player") # Acha o player na cena
@onready var label_vida = $Label3D


var vida_atual = 300
var tempo_ate_ataque := 0.0
var lentidao_restante := 0.0
var morrendo := false
var materiais_flash: Array[StandardMaterial3D] = []
var cores_originais: Array[Color] = []
var tween_flash: Tween

func _ready() -> void:
	add_to_group("inimigos")
	for no in find_children("*", "MeshInstance3D", true, false):
		var malha := no as MeshInstance3D
		var material := malha.get_active_material(0)
		if material is StandardMaterial3D:
			var material_flash := material.duplicate() as StandardMaterial3D
			malha.material_override = material_flash
			materiais_flash.append(material_flash)
			cores_originais.append(material_flash.albedo_color)

func _process(delta):
	label_vida.text = str(vida_atual) + (" | LENTO" if lentidao_restante > 0.0 else "")

func receber_dano(quantidade):
	_aplicar_dano(quantidade)

func receber_tiro(quantidade: int, posicao_impacto: Vector3, indice_forma: int = -1) -> String:
	var altura_local := to_local(posicao_impacto).y
	var tipo := "corpo"
	var dano_final := quantidade
	var zona_forma := ""
	if indice_forma >= 0:
		var id_dono_forma := shape_find_owner(indice_forma)
		var dono_forma := shape_owner_get_owner(id_dono_forma)
		if dono_forma is CollisionShape3D and dono_forma.has_meta("zona_acerto"):
			zona_forma = str(dono_forma.get_meta("zona_acerto"))
	if zona_forma == "cabeca" or (zona_forma.is_empty() and altura_local >= ALTURA_ACERTO_CABECA):
		tipo = "cabeca"
		dano_final = roundi(quantidade * MULTIPLICADOR_DANO_CABECA)
	elif zona_forma == "perna" or altura_local <= ALTURA_ACERTO_PERNA:
		tipo = "perna"
		lentidao_restante = DURACAO_LENTIDAO
	_aplicar_dano(dano_final)
	return tipo

func _aplicar_dano(quantidade: int) -> void:
	if morrendo:
		return
	# Subtrai o valor exato que a arma mandou da vida atual
	vida_atual -= quantidade
	print("Inimigo levou dano! Vida restante: ", vida_atual)
	_animar_dano()
	if player:
		var recuo := Vector3(global_position.x - player.global_position.x, 0.0, global_position.z - player.global_position.z).normalized()
		velocity += recuo * 2.2
	
	# Verifica se a vida chegou a zero ou menos
	if vida_atual <= 0:
		morrendo = true
		set_physics_process(false)
		collision_layer = 0
		collision_mask = 0
		for forma in find_children("*", "CollisionShape3D", true, false):
			(forma as CollisionShape3D).set_deferred("disabled", true)
		var tween_morte := create_tween()
		tween_morte.tween_property(self, "scale", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween_morte.finished.connect(queue_free)

func _animar_dano() -> void:
	if tween_flash and tween_flash.is_running():
		tween_flash.kill()
	tween_flash = create_tween().set_parallel(true)
	for indice in range(materiais_flash.size()):
		var material := materiais_flash[indice]
		tween_flash.tween_property(material, "albedo_color", Color(1.0, 0.25, 0.16), 0.055)
		tween_flash.tween_property(material, "albedo_color", cores_originais[indice], 0.19).set_delay(0.055).set_trans(Tween.TRANS_SINE)

func _physics_process(delta):
	tempo_ate_ataque = maxf(tempo_ate_ataque - delta, 0.0)
	lentidao_restante = maxf(lentidao_restante - delta, 0.0)
	# 1. Adiciona gravidade se não estiver no chão
	if not is_on_floor():
		velocity += get_gravity() * (delta * 1.6)

	# 2. Se o player existir na cena, persegue ele
	if player:
		# Faz o inimigo olhar para o player
		look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
		
		# Calcula a direção horizontal até o player (dá o "delay" natural de velocidade)
		var direction = (player.global_position - global_position).normalized()
		
		# Move devagar em direção ao player
		var velocidade_perseguicao := SPEED * (MULTIPLICADOR_LENTIDAO if lentidao_restante > 0.0 else 1.0)
		velocity.x = move_toward(velocity.x, direction.x * velocidade_perseguicao, delta * 10.0)
		velocity.z = move_toward(velocity.z, direction.z * velocidade_perseguicao, delta * 10.0)
	else:
		# Se o player morreu/sumiu, ele para
		velocity.x = move_toward(velocity.x, 0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0, delta * 10.0)

	move_and_slide()
	# O inimigo causa dano quando alcança o jogador, com intervalo entre ataques.
	if player and tempo_ate_ataque <= 0.0:
		var distancia_horizontal := Vector2(global_position.x - player.global_position.x, global_position.z - player.global_position.z).length()
		if distancia_horizontal <= 1.6 and player.has_method("receber_dano"):
			player.receber_dano(12)
			tempo_ate_ataque = 0.8
