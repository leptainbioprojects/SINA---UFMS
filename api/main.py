from typing import Literal

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

app = FastAPI(
    title="Mapa Assistivo API",
    version="0.1.0",
    description="Dados de prédios, rotas acessíveis e mapas por andar.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class Place(BaseModel):
    id: str
    name: str
    kind: str
    floor: int
    accessible_features: list[str] = Field(default_factory=list)
    position: tuple[float, float]


class RouteRequest(BaseModel):
    building_id: str = "aurora"
    origin_id: str = "entrance"
    destination_id: str
    accessibility: Literal["all", "wheelchair", "low_vision", "reduced_mobility"] = "all"


class RouteResponse(BaseModel):
    accessible: bool
    duration_minutes: int
    distance_meters: int
    instructions: list[str]
    floor_changes: int


PLACES = [
    Place(id="entrance", name="Entrada principal", kind="entrance", floor=0, accessible_features=["ramp", "tactile_path"], position=(0.16, 0.72)),
    Place(id="reception", name="Recepção", kind="service", floor=0, accessible_features=["libras", "audio_assistance"], position=(0.78, 0.20)),
    Place(id="elevator", name="Elevador", kind="vertical_access", floor=0, accessible_features=["wheelchair", "audio_assistance", "braille"], position=(0.40, 0.62)),
    Place(id="accessible_bathroom", name="Banheiro acessível", kind="bathroom", floor=1, accessible_features=["wheelchair", "grab_bars"], position=(0.64, 0.40)),
    Place(id="auditorium", name="Auditório", kind="room", floor=2, accessible_features=["wheelchair", "hearing_loop"], position=(0.78, 0.20)),
]


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "service": "mapa-assistivo-api"}


@app.get("/buildings/{building_id}/floors")
def floors(building_id: str) -> dict:
    return {
        "building_id": building_id,
        "floors": [
            {"number": 0, "name": "Térreo", "map_url": f"/maps/{building_id}/floor-0"},
            {"number": 1, "name": "1º andar", "map_url": f"/maps/{building_id}/floor-1"},
            {"number": 2, "name": "2º andar", "map_url": f"/maps/{building_id}/floor-2"},
        ],
    }


@app.get("/buildings/{building_id}/places", response_model=list[Place])
def places(building_id: str, floor: int | None = None) -> list[Place]:
    del building_id
    return [place for place in PLACES if floor is None or place.floor == floor]


@app.post("/routes", response_model=RouteResponse)
def route(request: RouteRequest) -> RouteResponse:
    destination = next((place for place in PLACES if place.id == request.destination_id), None)
    if destination is None:
        return RouteResponse(accessible=False, duration_minutes=0, distance_meters=0, instructions=["Destino não encontrado"], floor_changes=0)

    uses_accessible_path = request.accessibility in {"all", "wheelchair", "reduced_mobility"}
    return RouteResponse(
        accessible=uses_accessible_path,
        duration_minutes=4 + abs(destination.floor) * 2,
        distance_meters=180 + abs(destination.floor) * 65,
        instructions=["Siga a rota sinalizada até o elevador", f"Suba até o {destination.floor}º andar" if destination.floor else "Permaneça no térreo", f"Chegue a {destination.name}"],
        floor_changes=1 if destination.floor else 0,
    )
