# SINA---UFMS

Mapa Assistivo da UFMS: aplicativo Flutter para navegação acessível em prédios, com API Python/FastAPI.

Projeto inicial de um aplicativo Flutter para navegação acessível em prédios, com API Python/FastAPI.

## Estrutura

- `app/`: aplicativo Flutter responsivo com protótipo de planta por andar, filtros de acessibilidade e planejamento de rota.
- `api/`: API FastAPI com locais, andares e cálculo inicial de rota.

## Executar o app

```powershell
Set-Location app
flutter run
```

Validar:

```powershell
flutter analyze
flutter test
```

## Executar a API

É necessário instalar Python 3.11+ e adicionar o executável ao `PATH` do Windows. Depois:

```powershell
Set-Location api
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
uvicorn main:app --reload --host 127.0.0.1 --port 8080
```

Documentação interativa: `http://127.0.0.1:8080/docs`

Endpoints principais:

- `GET /health`
- `GET /buildings/{building_id}/floors`
- `GET /buildings/{building_id}/places?floor=1`
- `POST /routes`

A planta desenhada no Flutter é um mock visual para validar o fluxo. A próxima integração deve trocar o `CustomPainter` por dados GeoJSON/tiles ou um motor 3D, além de conectar o cliente Flutter à API.
