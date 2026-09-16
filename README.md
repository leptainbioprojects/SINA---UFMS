# Mapa Assistivo UFMS

Aplicativo Flutter para localizar ambientes e planejar rotas acessíveis em prédios da UFMS, com uma API Python/FastAPI responsável pelos dados dos locais e pelo cálculo das rotas.

## Estado atual

- Interface Flutter responsiva para desktop e web.
- Planta visual de exemplo desenhada com `CustomPainter`.
- Busca de ambientes no painel de planejamento.
- Filtros para todos, cadeira de rodas, baixa visão e mobilidade reduzida.
- Consulta de rota pela API em `POST /routes`.
- Botão para abrir o mapa da Cidade Universitária a partir de um PDF local salvo no app.
- Dados atuais ainda são demonstrativos; distâncias e instruções serão substituídas pelos dados das plantas arquitetônicas.

## Estrutura

```text
api/
  main.py              API FastAPI, locais e rotas
  requirements.txt     Dependências Python
app/
  assets/
    mapa_cidade_universitaria.pdf  Mapa local da Cidade Universitária
  lib/main.dart        Interface e interação do aplicativo Flutter
  test/                Testes de widgets
.vscode/launch.json    Configuração para iniciar o Flutter pelo VS Code
```

## Requisitos

- Python 3.10+
- Flutter SDK
- VS Code (opcional, mas recomendado)
- Android Studio + emulador Android (para testes mobile)

## Como trocar o PDF do mapa

1. Coloque o novo arquivo na pasta `app/assets/`.
2. Renomeie para `mapa_cidade_universitaria.pdf` ou ajuste o nome no código.
3. Verifique o caminho em `app/lib/main.dart` no campo `_campusMapAsset`.
4. Rode o app e teste o botão do mapa.

Exemplo:

```dart
static const String _campusMapAsset = 'assets/mapa_cidade_universitaria.pdf';
```

## Testando o botão do mapa

### Windows/Desktop

```powershell
Set-Location app
flutter run -d windows
```

Ao abrir o app, clique no botão do mapa na barra superior e confirme que o PDF abre com o leitor padrão do sistema.

### Android

```powershell
Set-Location app
flutter devices
flutter run -d <device_id>
```

Se estiver usando um emulador Android, confirme que a API está rodando em `http://10.0.2.2:8080`. Depois clique no botão do mapa e valide se o PDF é aberto corretamente.

## Como executar

### API

No primeiro uso, crie o ambiente e instale as dependências:

```powershell
Set-Location api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8080
```

A documentação interativa fica disponível em `http://127.0.0.1:8080/docs`.

### Aplicativo Flutter

Em outro terminal, na raiz do projeto:

```powershell
Set-Location app
flutter pub get
flutter run -d chrome
```

Também é possível pressionar `F5` no VS Code usando a configuração `Mapa Assistivo (Chrome)`.

No Chrome/Windows, o app usa `http://127.0.0.1:8080`. No Android Emulator,
`127.0.0.1` aponta para o próprio emulador, então o app usa automaticamente
`http://10.0.2.2:8080`, que representa o computador hospedeiro. Por isso a API
deve ser iniciada com `--host 0.0.0.0`.

## API

### `GET /health`

Verifica se a API está funcionando e retorna o status do serviço.

### `GET /buildings/{building_id}/floors`

Lista os andares disponíveis para um prédio e os caminhos dos mapas de cada andar.

### `GET /buildings/{building_id}/places?floor=1`

Lista os ambientes cadastrados. O parâmetro `floor` é opcional e filtra os ambientes de um andar específico.

### `POST /routes`

Calcula uma rota entre uma origem e um destino. Exemplo:

```json
{
  "building_id": "aurora",
  "origin_id": "entrance",
  "destination_id": "accessible_bathroom",
  "accessibility": "wheelchair"
}
```

Os valores aceitos para `accessibility` são `all`, `wheelchair`, `low_vision` e `reduced_mobility`.

## O que cada parte faz

### API: `api/main.py`

- `Place`: modelo de um ambiente, com nome, tipo, andar, recursos acessíveis e posição na planta.
- `RouteRequest`: dados recebidos para calcular uma rota.
- `RouteResponse`: formato da resposta, com acessibilidade, duração, distância, instruções e mudanças de andar.
- `PLACES`: cadastro temporário dos ambientes. Será substituído pelos dados extraídos das plantas arquitetônicas.
- `health()`: responde ao endpoint de verificação da API.
- `floors(building_id)`: retorna os andares de um prédio.
- `places(building_id, floor)`: lista e filtra os ambientes por andar.
- `route(request)`: localiza o destino e monta a resposta da rota. Atualmente usa valores demonstrativos; o próximo passo é trocar essa lógica por um algoritmo de caminho mínimo sobre um grafo do prédio.
- `CORSMiddleware`: permite que o Flutter Web local consulte a API em outra porta durante o desenvolvimento.

### Flutter: `app/lib/main.dart`

- `main()`: inicia o aplicativo.
- `AssistiveMapApp`: configura tema, título e tela inicial.
- `MapHomePage`: tela principal do mapa assistivo.
- `_MapHomePageState`: mantém o andar, destino, busca, filtro de acessibilidade e estado de carregamento da rota.
- `_filteredDestinations`: filtra os destinos conforme o texto pesquisado.
- `_requestRoute()`: envia destino e acessibilidade para `POST /routes` e atualiza o resumo da rota.
- `_openUfmsMap()`: carrega o PDF local da Cidade Universitária do asset do app e abre com o visualizador do sistema.
- `_wideLayout()` e `_compactLayout()`: escolhem o layout para telas largas ou estreitas.
- `_mapPanel()`: exibe o prédio, seletor de andar, planta e legenda.
- `_floorSelector()`: troca o andar visualizado.
- `_routePanel()`: exibe busca, destino, filtros, resumo e botão de rota.
- `_FloorMap`: widget que contém a planta desenhada.
- `_MapPainter`: desenha paredes, ambientes, caminho de exemplo e marcadores.
- `_Legend`: exibe um item da legenda de cores.
- `_Resource`: exibe um recurso acessível do prédio.

## Rotas baseadas em plantas arquitetônicas

As plantas podem ser usadas como fonte das rotas. O processo recomendado é:

1. Exportar cada planta para imagem, SVG, GeoJSON, DXF ou outro formato estruturado.
2. Marcar salas, corredores, portas, rampas, elevadores, escadas e obstáculos.
3. Criar nós para esses pontos e arestas para os trechos caminháveis.
4. Informar distância, andar e restrições de cada aresta.
5. Calcular o caminho com Dijkstra ou A*, aplicando penalidades ou bloqueios conforme o perfil de acessibilidade.
6. Enviar a sequência de pontos para o Flutter desenhar a rota sobre a planta.

Exemplo de uma aresta do grafo:

```json
{
  "from": "entrada",
  "to": "elevador",
  "distance": 42,
  "floor": 0,
  "accessible": true,
  "features": ["wheelchair", "tactile_path"]
}
```

O PDF local é a solução atual para disponibilizar a planta da Cidade Universitária sem depender de serviços externos. Ele é útil para consulta e localização do campus, mas ainda não substitui o cálculo interno de rotas sobre um grafo arquitetônico.

## Mapa local no app

O aplicativo agora usa um arquivo PDF salvo dentro do projeto em `app/assets/mapa_cidade_universitaria.pdf`. Quando o usuário toca no botão do mapa, o app copia esse arquivo para o diretório temporário e abre com o leitor padrão do sistema.

Essa abordagem funciona bem para distribuição local e evita a necessidade de uma chave de API externa. Para uma funcionalidade de mapa embutido e interativo no futuro, será necessário:

- criar uma chave no Google Cloud;
- ativar Maps SDK for Android/iOS e Maps JavaScript API para web;
- restringir a chave por aplicativo e domínio;
- configurar a chave nas plataformas do Flutter;
- verificar cobrança e limites da conta Google Cloud.

A chave não deve ser commitada no repositório. Use configuração por ambiente ou arquivos locais ignorados pelo Git.

## Validação

```powershell
Set-Location app
flutter analyze
flutter test
```

Para validar a sintaxe da API:

```powershell
Set-Location api
python -m compileall -q main.py
```
