extends Node3D

# Controlador da arena: inicia a run, cria hordas, sorteia inimigos e apresenta melhorias.
# Ponto de entrada do jogo: world.tscn usa este script no nó raiz "World".
const SCRIPT_ZUMBI = preload("res://zombie.gd")
const SCRIPT_DROP = preload("res://loot_pickup.gd")
const ARENA_LIMITE := 72.0

@onready var jogador: Variant = $player
@onready var hud: Variant = $player/Aim/HUD

var onda_atual := 0
var gerador := RandomNumberGenerator.new()

# Prepara decoração e aguarda o sinal de início emitido pelo menu do HUD.
func _ready() -> void:
	gerador.randomize()
	_criar_escombros()
	# A run só começa quando o jogador confirma no menu principal.
	get_tree().paused = true
	_loop_de_hordas.call_deferred()

# Repete as hordas e interrompe o combate entre ondas para oferecer três melhorias.
func _loop_de_hordas() -> void:
	# Espera o sinal do botão Iniciar antes de criar a primeira horda.
	await hud.jogo_iniciado
	await get_tree().create_timer(2.0, false).timeout
	while jogador.vida_atual > 0:
		onda_atual += 1
		var total := mini(4 + onda_atual * 2, 28)
		hud.atualizar_onda(onda_atual, total)
		hud.mostrar_mensagem("ONDA %02d - CONTATO IMINENTE" % onda_atual)
		await get_tree().create_timer(1.2, false).timeout
		for indice in range(total):
			if jogador.vida_atual <= 0:
				break
			_criar_zumbi(_sortear_tipo_zumbi(), onda_atual)
			hud.atualizar_onda(onda_atual, total)
			await get_tree().create_timer(maxf(0.82 - onda_atual * 0.035, 0.28), false).timeout

		while jogador.vida_atual > 0 and not get_tree().get_nodes_in_group("inimigos").is_empty():
			hud.atualizar_onda(onda_atual, total)
			await get_tree().create_timer(0.3, false).timeout
		if jogador.vida_atual <= 0:
			break

		hud.mostrar_mensagem("ONDA %02d CONCLUIDA" % onda_atual)
		jogador.preparar_proxima_onda()
		await get_tree().create_timer(1.0, false).timeout
		var opcoes := _sortear_melhorias()
		get_tree().paused = true
		hud.abrir_melhorias(opcoes, onda_atual)
		var escolha: int = await hud.melhoria_escolhida
		get_tree().paused = false
		jogador.aplicar_melhoria(str(opcoes[escolha].id))
		hud.atualizar_onda(onda_atual + 1, 0)
		await get_tree().create_timer(1.2, false).timeout

	if jogador.vida_atual <= 0:
		get_tree().paused = true
		hud.mostrar_fim_de_jogo(onda_atual)

# Cria um zumbi configurado para o tipo e a dificuldade da onda atual.
func _criar_zumbi(tipo: String, numero_onda: int) -> void:
	var zumbi := SCRIPT_ZUMBI.new() as CharacterBody3D
	zumbi.call("configurar", tipo, numero_onda)
	zumbi.global_position = _sortear_ponto_de_entrada()
	add_child(zumbi)

# Escolhe um ponto de entrada nas bordas da arena, distante do jogador.
func _sortear_ponto_de_entrada() -> Vector3:
	var melhor_ponto := Vector3.ZERO
	var maior_distancia := -1.0
	for tentativa in range(12):
		var deslocamento := gerador.randf_range(-ARENA_LIMITE, ARENA_LIMITE)
		var ponto := Vector3.ZERO
		match gerador.randi_range(0, 3):
			0: ponto = Vector3(-ARENA_LIMITE, 0.0, deslocamento)
			1: ponto = Vector3(ARENA_LIMITE, 0.0, deslocamento)
			2: ponto = Vector3(deslocamento, 0.0, -ARENA_LIMITE)
			3: ponto = Vector3(deslocamento, 0.0, ARENA_LIMITE)
		var distancia := Vector2(ponto.x - jogador.global_position.x, ponto.z - jogador.global_position.z).length()
		if distancia > maior_distancia:
			maior_distancia = distancia
			melhor_ponto = ponto
		if distancia >= 22.0:
			return ponto
	return melhor_ponto

# A composição das hordas muda à medida que a run avança.
func _sortear_tipo_zumbi() -> String:
	var rolagem := gerador.randf()
	if onda_atual >= 5:
		if rolagem < 0.12:
			return "cuspidor"
		if rolagem < 0.27:
			return "brutamontes"
		if rolagem < 0.55:
			return "corredor"
	elif onda_atual >= 3:
		if rolagem < 0.16:
			return "brutamontes"
		if rolagem < 0.48:
			return "corredor"
	elif onda_atual >= 2 and rolagem < 0.35:
		return "corredor"
	return "andante"

# Sorteia três melhorias distintas, primeiro determinando a raridade de cada carta.
func _sortear_melhorias() -> Array[Dictionary]:
	var pool: Array[Dictionary] = [
		{"id":"calibre", "titulo":"Calibre magnum", "descricao":"+30% dano por tiro.\nDispersao sobe 1 grau.", "raridade":"Incomum"},
		{"id":"tambor", "titulo":"Tambor estendido", "descricao":"+30 munições na reserva e no limite.\nRecarga +0,2 segundo.", "raridade":"Comum"},
		{"id":"botas", "titulo":"Estimulantes", "descricao":"+1 m/s de velocidade.\nDispersao sobe 1,5 grau.", "raridade":"Incomum"},
		{"id":"colete", "titulo":"Colete reforcado", "descricao":"+25 vida maxima e cura.\nVelocidade -0,6 m/s.", "raridade":"Comum"},
		{"id":"estabilizador", "titulo":"Empunhadura firme", "descricao":"Dispersao -28%.\nVelocidade -0,5 m/s.", "raridade":"Comum"},
		{"id":"recarga", "titulo":"Mecanismo rapido", "descricao":"Recarga 28% mais rapida.\nLimite da reserva -20.", "raridade":"Incomum"},
		{"id":"municao_perfurante", "titulo":"Ponta perfurante", "descricao":"+22% dano.\nLimite da reserva -20.", "raridade":"Raro"},
		{"id":"adrenalina", "titulo":"Adrenalina", "descricao":"+18% velocidade e cura 20.\nVida maxima -10.", "raridade":"Raro"},
		{"id":"sifao", "titulo":"Sifao vital", "descricao":"Abates restauram 3 de vida.\nDano recebido +12%.", "raridade":"Epico"},
		{"id":"ricochete", "titulo":"Nucleo de ricochete", "descricao":"+35% dano.\nDispersao +3 graus.", "raridade":"Epico"},
		{"id":"sobrecarrega", "titulo":"Reator instavel", "descricao":"+55% dano e +25% velocidade.\nVida maxima -30.", "raridade":"Lendario"},
		{"id":"segunda_chance", "titulo":"Protocolo Phoenix", "descricao":"Uma vez por run, volta com 35 de vida.\nVelocidade -10%.", "raridade":"Lendario"},
		{"id":"mira_laser", "titulo":"Mira laser", "descricao":"Dispersao -45%.\nVelocidade de recarga +15% lenta.", "raridade":"Raro"},
		{"id":"casca", "titulo":"Casca reforcada", "descricao":"Recebe 18% menos dano.\nVelocidade -0,8 m/s.", "raridade":"Epico"},
		{"id":"catador", "titulo":"Instinto de catador", "descricao":"Drops de municao mais frequentes.\nDano -8%.", "raridade":"Incomum"},
		{"id":"sangue_quente", "titulo":"Sangue quente", "descricao":"+30 vida maxima.\nDispersao +2 graus.", "raridade":"Comum"},
		{"id":"gatilho", "titulo":"Gatilho leve", "descricao":"+20% velocidade de recarga.\nDano -10%.", "raridade":"Raro"}
	]
	var escolhas: Array[Dictionary] = []
	for indice in range(3):
		var raridade := _sortear_raridade_melhoria()
		var candidatos: Array[int] = []
		for posicao in range(pool.size()):
			if pool[posicao].raridade == raridade:
				candidatos.append(posicao)
		if candidatos.is_empty():
			candidatos.append(gerador.randi_range(0, pool.size() - 1))
		var sorteado: int = candidatos[gerador.randi_range(0, candidatos.size() - 1)]
		var melhoria_sorteada: Dictionary = pool.pop_at(sorteado)
		escolhas.append(melhoria_sorteada)
	return escolhas

# Distribuição das raridades: lendário é raro de propósito para manter o equilíbrio.
func _sortear_raridade_melhoria() -> String:
	var rolagem := gerador.randf()
	if rolagem < 0.02:
		return "Lendario"
	if rolagem < 0.10:
		return "Epico"
	if rolagem < 0.28:
		return "Raro"
	if rolagem < 0.58:
		return "Incomum"
	return "Comum"

# Cria um item coletável no ponto em que o zumbi foi abatido.
func criar_drop(posicao: Vector3, tipo: String) -> void:
	var drop := SCRIPT_DROP.new() as Node3D
	drop.configurar(tipo)
	add_child(drop)
	drop.global_position = posicao + Vector3(0.0, 0.35, 0.0)

# Adiciona peças visuais de cenário sem colisão para dar leitura à arena.
func _criar_escombros() -> void:
	var pontos := [Vector3(-22, 0, -8), Vector3(18, 0, -18), Vector3(30, 0, 12), Vector3(-34, 0, 21), Vector3(5, 0, 43), Vector3(-48, 0, -34), Vector3(49, 0, -42), Vector3(40, 0, 48)]
	var rng_visual := RandomNumberGenerator.new()
	rng_visual.randomize()
	for ponto in pontos:
		for pedaco in range(3):
			var destroco := MeshInstance3D.new()
			var malha := BoxMesh.new()
			malha.size = Vector3(rng_visual.randf_range(0.8, 2.6), rng_visual.randf_range(0.3, 1.1), rng_visual.randf_range(0.7, 2.0))
			destroco.mesh = malha
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.13, 0.16, 0.14).lerp(Color(0.34, 0.29, 0.21), rng_visual.randf())
			material.roughness = 1.0
			destroco.material_override = material
			destroco.position = ponto + Vector3(rng_visual.randf_range(-2.2, 2.2), malha.size.y * 0.5, rng_visual.randf_range(-2.2, 2.2))
			destroco.rotation.y = rng_visual.randf_range(0.0, TAU)
			add_child(destroco)
