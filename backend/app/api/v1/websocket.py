import asyncio
import json
import uuid
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["realtime"])

_branch_connections: dict[str, set[WebSocket]] = {}


@router.websocket("/ws/inventory/{branch_id}")
async def inventory_ws(websocket: WebSocket, branch_id: uuid.UUID):
    key = str(branch_id)
    await websocket.accept()
    _branch_connections.setdefault(key, set()).add(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        _branch_connections.get(key, set()).discard(websocket)


async def broadcast_inventory_update(branch_id: uuid.UUID, event: dict[str, Any]) -> None:
    key = str(branch_id)
    dead: set[WebSocket] = set()
    for ws in _branch_connections.get(key, set()):
        try:
            await ws.send_text(json.dumps(event, default=str))
        except Exception:
            dead.add(ws)
    _branch_connections.get(key, set()).difference_update(dead)
