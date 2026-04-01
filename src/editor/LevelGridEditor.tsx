import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { EditorTile, type TileValue } from './editorTypes'
import { mirroredRightGlobalX } from '../game/board/spawns'
import './levelEditor.css'

export type DrawMode = 'paint' | 'line' | 'rect'

type Props = {
  tiles: TileValue[][]
  onChange: (next: TileValue[][]) => void
  selected: EditorTile
  drawMode: DrawMode
  pacSpawn: { x: number; y: number }
  leftFruitSpawn: { x: number; y: number }
}

function clone2D(a: TileValue[][]): TileValue[][] {
  return a.map((row) => row.slice() as TileValue[])
}

export function LevelGridEditor({
  tiles,
  onChange,
  selected,
  drawMode,
  pacSpawn,
  leftFruitSpawn,
}: Props) {
  const height = tiles.length
  const halfWidth = tiles[0]?.length ?? 0
  const width = halfWidth * 2

  const [isPainting, setIsPainting] = useState(false)
  const lastPaintRef = useRef<{ x: number; y: number } | null>(null)
  const [dragStart, setDragStart] = useState<{ x: number; y: number } | null>(null)
  const [dragCurrent, setDragCurrent] = useState<{ x: number; y: number } | null>(null)

  const colorFor = useMemo(() => {
    return {
      [EditorTile.Empty]: 'rgba(15, 23, 42, 0.25)',
      [EditorTile.Pellet]: 'rgba(251, 191, 36, 0.9)',
      [EditorTile.Wall]: 'rgba(59, 130, 246, 0.9)',
      [EditorTile.Exit]: 'rgba(15, 23, 42, 0.25)',
      [EditorTile.GhostHouse]: 'rgba(239, 68, 68, 0.9)',
      [EditorTile.PowerPellet]: 'rgba(249, 115, 22, 0.9)',
    } as const
  }, [])

  useEffect(() => {
    const onUp = () => {
      setIsPainting(false)
      lastPaintRef.current = null
      setDragStart(null)
      setDragCurrent(null)
    }
    window.addEventListener('mouseup', onUp)
    window.addEventListener('blur', onUp)
    return () => {
      window.removeEventListener('mouseup', onUp)
      window.removeEventListener('blur', onUp)
    }
  }, [])

  const paint = (x: number, y: number) => {
    if (y < 0 || y >= height || x < 0 || x >= halfWidth) return
    const last = lastPaintRef.current
    if (last && last.x === x && last.y === y) return
    lastPaintRef.current = { x, y }

    const current = tiles[y]![x]!
    const nextVal = selected as unknown as TileValue
    if (current === nextVal) return

    const next = clone2D(tiles)
    next[y]![x] = nextVal
    onChange(next)
  }

  const linePoints = (x0: number, y0: number, x1: number, y1: number) => {
    const pts: Array<{ x: number; y: number }> = []
    let x = x0
    let y = y0
    const dx = Math.abs(x1 - x0)
    const sx = x0 < x1 ? 1 : -1
    const dy = -Math.abs(y1 - y0)
    const sy = y0 < y1 ? 1 : -1
    let err = dx + dy
    while (true) {
      pts.push({ x, y })
      if (x === x1 && y === y1) break
      const e2 = 2 * err
      if (e2 >= dy) {
        err += dy
        x += sx
      }
      if (e2 <= dx) {
        err += dx
        y += sy
      }
    }
    return pts
  }

  const drawLine = (x0: number, y0: number, x1: number, y1: number) => {
    const next = clone2D(tiles)
    const nextVal = selected as unknown as TileValue
    for (const { x, y } of linePoints(x0, y0, x1, y1)) {
      if (x >= 0 && x < halfWidth && y >= 0 && y < height) next[y]![x] = nextVal
    }
    onChange(next)
  }

  const rectBounds = useCallback(
    (x0: number, y0: number, x1: number, y1: number) => {
      return {
        minX: Math.max(0, Math.min(x0, x1)),
        maxX: Math.min(halfWidth - 1, Math.max(x0, x1)),
        minY: Math.max(0, Math.min(y0, y1)),
        maxY: Math.min(height - 1, Math.max(y0, y1)),
      }
    },
    [halfWidth, height],
  )

  const drawRectFilled = (x0: number, y0: number, x1: number, y1: number) => {
    const next = clone2D(tiles)
    const nextVal = selected as unknown as TileValue
    const { minX, maxX, minY, maxY } = rectBounds(x0, y0, x1, y1)
    for (let y = minY; y <= maxY; y++) {
      for (let x = minX; x <= maxX; x++) {
        next[y]![x] = nextVal
      }
    }
    onChange(next)
  }

  const previewCells = useMemo(() => {
    if (!isPainting || drawMode === 'paint' || !dragStart || !dragCurrent) {
      return new Set<string>()
    }
    const out = new Set<string>()
    if (drawMode === 'line') {
      for (const { x, y } of linePoints(dragStart.x, dragStart.y, dragCurrent.x, dragCurrent.y)) {
        if (x >= 0 && x < halfWidth && y >= 0 && y < height) out.add(`${x},${y}`)
      }
      return out
    }
    const { minX, maxX, minY, maxY } = rectBounds(
      dragStart.x,
      dragStart.y,
      dragCurrent.x,
      dragCurrent.y,
    )
    for (let x = minX; x <= maxX; x++) {
      for (let y = minY; y <= maxY; y++) {
        out.add(`${x},${y}`)
      }
    }
    return out
  }, [drawMode, dragCurrent, dragStart, halfWidth, height, isPainting, rectBounds])

  const tileAt = (x: number, y: number) => {
    if (x < halfWidth) return tiles[y]![x]!
    const mirrorX = width - 1 - x
    return tiles[y]![mirrorX]!
  }

  return (
    <div className="gridWrap">
      <div
        className="grid"
        style={{
          gridTemplateColumns: `repeat(${width}, 18px)`,
          gridTemplateRows: `repeat(${height}, 18px)`,
        }}
        onMouseLeave={() => {
          lastPaintRef.current = null
        }}
      >
        {Array.from({ length: height }, (_, y) =>
          Array.from({ length: width }, (_, x) => {
            const t = tileAt(x, y)
            const isRightGhost = x >= halfWidth
            const isPacSpawn = !isRightGhost && x === pacSpawn.x && y === pacSpawn.y
            const fruitY = leftFruitSpawn.y
            const fruitLeftX = leftFruitSpawn.x
            const fruitRightX = mirroredRightGlobalX(leftFruitSpawn.x, halfWidth)
            const isFruitSpawn =
              y === fruitY && (x === fruitLeftX || x === fruitRightX)
            return (
              <button
                key={`${x},${y}`}
                className={`cell${isRightGhost ? ' cell--ghost' : ''}${isPacSpawn ? ' cell--pac-spawn' : ''}${isFruitSpawn ? ' cell--fruit-spawn' : ''}`}
                style={{
                  background:
                    colorFor[t],
                  boxShadow:
                    t === EditorTile.Exit
                      ? 'inset 0 -7px 0 rgba(248,250,252,0.96), inset 0 -10px 0 rgba(15,23,42,0)'
                      : undefined,
                }}
                onMouseDown={(e) => {
                  if (isRightGhost) return
                  e.preventDefault()
                  setIsPainting(true)
                  setDragStart({ x, y })
                  setDragCurrent({ x, y })
                  if (drawMode === 'paint') paint(x, y)
                }}
                onMouseEnter={() => {
                  if (isRightGhost) return
                  if (!isPainting) return
                  setDragCurrent({ x, y })
                  if (drawMode !== 'paint') return
                  paint(x, y)
                }}
                onMouseUp={() => {
                  if (isRightGhost) return
                  const start = dragStart ?? { x, y }
                  if (drawMode === 'line') drawLine(start.x, start.y, x, y)
                  if (drawMode === 'rect') drawRectFilled(start.x, start.y, x, y)
                }}
                data-preview={previewCells.has(`${x},${y}`) ? '1' : '0'}
                title={`${x},${y}${isRightGhost ? ' (mirrored preview)' : ''}`}
                disabled={isRightGhost}
              />
            )
          }),
        )}
      </div>
    </div>
  )
}

