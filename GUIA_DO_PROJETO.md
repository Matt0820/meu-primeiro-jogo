# Guia rápido do projeto

Este jogo é montado principalmente por scripts GDScript e pela cena `world.tscn`.
Os comentários foram adicionados perto das funções para facilitar a alteração das telas e da HUD.

## Estrutura da cena

- `World` (`world.gd`): arena, hordas, sorteio de zumbis, melhorias e drops.
- `World/player` (`character_body_3d.gd`): movimento, câmera, arma, vida e efeitos das melhorias.
- `World/player/player_camera`: câmera de primeira pessoa; o script `camera_movement_x.gd` controla o eixo vertical.
- `World/player/Aim/HUD` (`hud.gd`): mira, indicadores, menu inicial, pausa, configurações e escolha de melhorias.
- Os zumbis são criados em tempo de execução por `zombie.gd`; `loot_pickup.gd` implementa os drops.

## Onde desenhar ou reorganizar a HUD

Em `hud.gd`, procure `_criar_hud()` para os elementos de combate e `_draw()` para o retículo e o marcador de acerto. Os textos e barras são atualizados por `atualizar()`, `atualizar_onda()` e `atualizar_modulos()`.

Os menus usam `_criar_base_menu()` e `_criar_botao_menu()` como base visual. As telas específicas ficam em `_criar_menu_inicial()`, `_abrir_menu_pausa()` e `_abrir_configuracoes()`. As opções de resolução são montadas em `_abrir_configuracoes()` e aplicadas em `_aplicar_configuracoes_video()`.

## Fluxo da partida

1. O HUD abre o menu inicial e pausa a árvore.
2. `INICIAR RUN` emite `jogo_iniciado`; `world.gd` então começa o ciclo de hordas.
3. `ESC` abre ou fecha a pausa; os botões de configurações e saída são controlados pelo HUD.
4. Ao limpar uma onda, `world.gd` pausa o jogo e oferece três melhorias.
5. O jogador coleta medkits e munição ao se aproximar dos itens criados pelo zumbi abatido. A munição coletada entra na reserva; `R` transfere da reserva para o pente, e ondas novas não reabastecem munição.

## Atalhos

- `WASD`: movimentar.
- Mouse: mirar.
- Clique esquerdo: disparar.
- `R`: recarregar.
- `Espaço`: pular.
- `ESC`: pausar/retomar ou voltar das configurações.
- `Shift`: correr; `C` durante a corrida: deslizar e empurrar zumbis.
- `1` / `2` ou `Q`: selecionar pistola/faca ou alternar entre elas.
