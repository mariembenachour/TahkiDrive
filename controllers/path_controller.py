# controllers/path_controller.py
from fastapi import APIRouter, Depends, HTTPException, Query
from dependencies import get_current_user
from services.path_service import get_recent_paths, get_path_by_id
from models.path import Path

router = APIRouter(prefix="/paths", tags=["Trajets"])


@router.get("", response_model=dict)
def list_paths(
    limit:  int = Query(default=5,  ge=1, le=50),
    offset: int = Query(default=0,  ge=0),
    cin:    str = Depends(get_current_user),
):
    grouped = get_recent_paths(cin=cin, limit=limit, offset=offset)
    return {
        "today":     [p.model_dump() for p in grouped["today"]],
        "yesterday": [p.model_dump() for p in grouped["yesterday"]],
        "older":     [p.model_dump() for p in grouped["older"]],
        "total":     sum(len(v) for v in grouped.values()),
        "limit":     limit,
        "offset":    offset,
    }


@router.get("/{path_id}", response_model=Path)
def get_path(
    path_id: int,
    cin:     str = Depends(get_current_user),
):
    """
    Retourne le détail d'un trajet par son ID.
    Vérifie que le trajet appartient bien au device du chauffeur connecté.
    """
    path = get_path_by_id(cin=cin, path_id=path_id)
    if not path:
        raise HTTPException(
            status_code=404,
            detail="Trajet introuvable ou non autorisé",
        )
    return path