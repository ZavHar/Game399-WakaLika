import { Tile } from '../board/levels'
import { isWall, tileType } from '../board/grid'
import { findPathBfs } from '../ghosts/pathfinding'
import { getBoardSpriteSet, getWallSpriteRect, wallNeighborMask } from './tileSprites'
import {
  drawGameOverOverlay,
  drawHudBar,
} from './renderHud'
import {
  GHOST_LIGHT_ALPHA,
  GHOST_LIGHT_RADIUS_TILES,
  FEAR_FLASH_MS,
  FRUIT_SIDE_FLASH_FADE_POW,
  FRUIT_SIDE_FLASH_MAX_ALPHA,
  FRUIT_SIDE_FLASH_DURATION_MS,
  PACLIGHT_COLOR,
  PACLIGHT_MAX_ALPHA,
  PACLIGHT_RADIUS_TILES,
  LIGHT_RADIAL_EASING_EXPONENT,
} from '../data/constants'
import { LEFT_FRUIT_SPAWN_LOCAL, mirroredRightGlobalX } from '../board/spawns'
import type { GameState, TileSlideAnim } from '../data/types'
import { lerp } from '../data/utils'

function ghostBodyColor(id: GameState['ghosts'][0]['id']): string {
  switch (id) {
    case 'red':
      return '#dc2626' // clear red (distinct from pink)
    case 'pink':
      return '#f472b6' // magenta pink
    case 'blue':
      return '#22d3ee' // cyan
    case 'orange':
      return '#fb923c' // orange (was yellow in default)
    default:
      return '#94a3b8'
  }
}

function ghostVisualColor(g: GameState['ghosts'][0], state: GameState): string {
  // Incapacitated has its own rendering rules elsewhere (eyes-only), but keep this stable.
  if (g.isIncapacitated) return ghostBodyColor(g.id)
  if (state.fearMs <= 0) return ghostBodyColor(g.id)

  const fearBlue = '#1e3a8a'
  if (state.fearMs > FEAR_FLASH_MS) return fearBlue

  // Flash between fear-blue and white as fear expires.
  const flashOn = Math.floor(state.fearMs / 150) % 2 === 0
  return flashOn ? '#ffffff' : fearBlue
}

const WALL_TINT_COLOR = 'rgba(0, 48, 206, 0.65)' // deep blue
const WALL_DARK_TINT_RGB = '2, 6, 23'
const SIDE_CLEAR_DARK_MAX = 0.45
const SIDE_CLEAR_DARK_MIN_NEAR_SEAM = 0
const SIDE_CLEAR_SEAM_FALLOFF_TILES = 3

/** Offscreen canvases: wall lines must stay on a layer with real transparency so
 *  source-atop tint / side-clear and wall lights only affect drawn wall pixels (not full tile rects). */
function ensureScratchCanvas(
  ref: { current: HTMLCanvasElement | null },
  nextW: number,
  nextH: number,
): HTMLCanvasElement {
  if (!ref.current || ref.current.width !== nextW || ref.current.height !== nextH) {
    ref.current = document.createElement('canvas')
    ref.current.width = nextW
    ref.current.height = nextH
  }
  return ref.current
}

const wallScratchRef = { current: null as HTMLCanvasElement | null }
const lightScratchRef = { current: null as HTMLCanvasElement | null }

function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const m = hex.trim().match(/^#?([0-9a-f]{6})$/i)
  if (!m) return { r: 255, g: 255, b: 255 }
  const n = parseInt(m[1]!, 16)
  return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 }
}

function addRadialGradientEasedStops(opts: {
  grad: CanvasGradient
  colorPrefix: string
  maxAlpha: number
  easingExp: number
}) {
  const {
    grad,
    colorPrefix,
    maxAlpha,
    easingExp,
  } = opts

  // More stops = smoother "eased" look. Keep this small since this runs per light.
  const STOP_COUNT = 6
  const exp = Math.max(0.0001, easingExp)

  for (let i = 0; i <= STOP_COUNT; i++) {
    const t = i / STOP_COUNT // 0 at center, 1 at max radius
    // Alpha = maxAlpha at the center, tapering off with easing toward radius edge.
    const alpha = maxAlpha * (1 - Math.pow(t, exp))
    const rgba = `${colorPrefix}${alpha})`
    grad.addColorStop(i / STOP_COUNT, rgba)
  }
}

export function drawGame(
  ctx: CanvasRenderingContext2D,
  canvas: HTMLCanvasElement,
  state: GameState,
  ghostAnims: TileSlideAnim[],
  opts?: { showGhostPaths?: boolean },
) {
  const w = canvas.width
  const h = canvas.height
  const { leftHalf } = state
  const splitX = leftHalf.width
  const bw = leftHalf.width + state.rightHalf.width
  const bh = leftHalf.height
  const leftClearProg = Math.max(0, Math.min(1, state.leftSideClearProgress))
  const rightClearProg = Math.max(0, Math.min(1, state.rightSideClearProgress))
  const pacX = state.pacPosition.x
  const pacY = state.pacPosition.y

  ctx.clearRect(0, 0, w, h)
  ctx.fillStyle = '#020617'
  ctx.fillRect(0, 0, w, h)

  const margin = 36 * (window.devicePixelRatio || 1)
  const tileSize = Math.min(
    (w - margin * 2) / bw,
    (h - margin * 2) / bh,
  )
  const offsetX = (w - bw * tileSize) / 2
  const offsetY = (h - bh * tileSize) / 2
  const sprites = getBoardSpriteSet()
  ctx.imageSmoothingEnabled = true

  // Snap tile edges to integer device pixels so adjacent tiles share exact borders.
  const xEdges = Array.from({ length: bw + 1 }, (_, i) =>
    Math.round(offsetX + i * tileSize),
  )
  const yEdges = Array.from({ length: bh + 1 }, (_, i) =>
    Math.round(offsetY + i * tileSize),
  )
  const dpr = window.devicePixelRatio || 1
  const tileCenter = (tx: number, ty: number) => ({
    x: offsetX + tx * tileSize + tileSize / 2,
    y: offsetY + ty * tileSize + tileSize / 2,
  })

  // Warp duplicate rendering:
  // When an entity is close to a board edge, render a second copy shifted by
  // exactly one full board width/height. This makes warp transitions feel continuous.
  const ENTITY_DUP_THRESHOLD_TILES = 3
  const pacRenderPositions: Array<{ x: number; y: number }> = [{ x: pacX, y: pacY }]
  if (pacX <= ENTITY_DUP_THRESHOLD_TILES) {
    pacRenderPositions.push({ x: pacX + bw, y: pacY })
  } else if (pacX >= bw - ENTITY_DUP_THRESHOLD_TILES) {
    pacRenderPositions.push({ x: pacX - bw, y: pacY })
  }
  if (pacY <= ENTITY_DUP_THRESHOLD_TILES) {
    pacRenderPositions.push({ x: pacX, y: pacY + bh })
  } else if (pacY >= bh - ENTITY_DUP_THRESHOLD_TILES) {
    pacRenderPositions.push({ x: pacX, y: pacY - bh })
  }
  const fruitPos = (side: 'left' | 'right') =>
    side === 'left'
      ? {
          x: LEFT_FRUIT_SPAWN_LOCAL.x,
          y: LEFT_FRUIT_SPAWN_LOCAL.y,
        }
      : {
          x: mirroredRightGlobalX(LEFT_FRUIT_SPAWN_LOCAL.x, state.leftHalf.width),
          y: LEFT_FRUIT_SPAWN_LOCAL.y,
        }

  const wallRects: Array<{
    px: number
    py: number
    pw: number
    ph: number
    tileX: number
  }> = []

  const showGhostPaths = opts?.showGhostPaths ?? false

  // Draw ghost paths first so they stay behind all tiles/entities.
  if (showGhostPaths) {
    for (let gi = 0; gi < state.ghosts.length; gi++) {
    const g = state.ghosts[gi]
    const ga = ghostAnims[gi]

    // Fear-mode ghosts do not use BFS pathfinding; don't draw stale BFS routes.
    const isFeared = !g.isIncapacitated && state.fearMs > 0
    if (isFeared) continue

    const startCell = { x: g.position.x, y: g.position.y }

    const onGhostHouse = tileType(g.position.x, g.position.y, state) === Tile.GhostHouse
    const allowExitDoor =
      g.isIncapacitated && g.incapacitatedPhase === 'return_to_house'
    const restrictToGhostHouse =
      g.isIncapacitated && g.incapacitatedPhase === 'waiting_in_house' && onGhostHouse

    const path = findPathBfs(startCell, g.destination, state, g.direction, {
      allowExitDoor,
      restrictToGhostHouse,
    })
    if (!path || path.length < 2) continue
    const sx = ga ? lerp(ga.from.x, ga.to.x, ga.t) : g.position.x
    const sy = ga ? lerp(ga.from.y, ga.to.y, ga.t) : g.position.y
    const startPt = {
      x: offsetX + sx * tileSize + tileSize / 2,
      y: offsetY + sy * tileSize + tileSize / 2,
    }

    ctx.save()
    ctx.strokeStyle = ghostVisualColor(g, state)
    ctx.globalAlpha = 0.35
    ctx.lineWidth = Math.max(1, 2 * dpr)
    ctx.beginPath()
    ctx.moveTo(startPt.x, startPt.y)
    let prevCell = path[0]!

    for (let i = 0; i < path.length; i++) {
      const curCell = path[i]!
      const p = tileCenter(path[i].x, path[i].y)
      // Detect warp jumps and draw only an "off-board" continuation.
      // Example: bw-1 -> 0 (wrap horizontally) should draw off the right edge,
      // then jump/pen-up to the entering tile without cross-screen line.
      const warpXRight = prevCell.y === curCell.y && prevCell.x === bw - 1 && curCell.x === 0
      const warpXLeft = prevCell.y === curCell.y && prevCell.x === 0 && curCell.x === bw - 1
      const warpYDown = prevCell.x === curCell.x && prevCell.y === bh - 1 && curCell.y === 0
      const warpYUp = prevCell.x === curCell.x && prevCell.y === 0 && curCell.y === bh - 1

      const warpHappened = warpXRight || warpXLeft || warpYDown || warpYUp

      if (warpHappened) {
        if (warpXRight) {
          const leavingX = offsetX + bw * tileSize + tileSize / 2
          const leavingY = offsetY + prevCell.y * tileSize + tileSize / 2
          ctx.lineTo(leavingX, leavingY)
          // Enter from the opposite side (off-board) into the entering tile.
          const enteringX = offsetX - tileSize / 2
          const enteringY = offsetY + curCell.y * tileSize + tileSize / 2
          ctx.moveTo(enteringX, enteringY)
          ctx.lineTo(p.x, p.y)
        } else if (warpXLeft) {
          const leavingX = offsetX - tileSize / 2
          const leavingY = offsetY + prevCell.y * tileSize + tileSize / 2
          ctx.lineTo(leavingX, leavingY)
          const enteringX = offsetX + bw * tileSize + tileSize / 2
          const enteringY = offsetY + curCell.y * tileSize + tileSize / 2
          ctx.moveTo(enteringX, enteringY)
          ctx.lineTo(p.x, p.y)
        } else if (warpYDown) {
          const leavingY = offsetY + bh * tileSize + tileSize / 2
          const leavingX = offsetX + prevCell.x * tileSize + tileSize / 2
          ctx.lineTo(leavingX, leavingY)
          const enteringY = offsetY - tileSize / 2
          const enteringX = offsetX + curCell.x * tileSize + tileSize / 2
          ctx.moveTo(enteringX, enteringY)
          ctx.lineTo(p.x, p.y)
        } else if (warpYUp) {
          const leavingY = offsetY - tileSize / 2
          const leavingX = offsetX + prevCell.x * tileSize + tileSize / 2
          ctx.lineTo(leavingX, leavingY)
          const enteringY = offsetY + bh * tileSize + tileSize / 2
          const enteringX = offsetX + curCell.x * tileSize + tileSize / 2
          ctx.moveTo(enteringX, enteringY)
          ctx.lineTo(p.x, p.y)
        }
      } else {
        ctx.lineTo(p.x, p.y)
      }
      prevCell = curCell
    }
      ctx.stroke()
      ctx.restore()
    }
  }

  const wallCanvas = ensureScratchCanvas(wallScratchRef, w, h)
  const wallCtx = wallCanvas.getContext('2d')!
  wallCtx.clearRect(0, 0, w, h)
  wallCtx.imageSmoothingEnabled = ctx.imageSmoothingEnabled

  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      if (!isWall(x, y, state)) continue
      const px = xEdges[x]
      const py = yEdges[y]
      const pw = xEdges[x + 1] - xEdges[x]
      const ph = yEdges[y + 1] - yEdges[y]
      wallRects.push({ px, py, pw, ph, tileX: x })

      const mask = wallNeighborMask((dx, dy) => isWall(x + dx, y + dy, state))
      const wallRect = getWallSpriteRect(mask)
      if (sprites) {
        wallCtx.drawImage(
          sprites.wallAtlas,
          wallRect.sx,
          wallRect.sy,
          wallRect.sw,
          wallRect.sh,
          px,
          py,
          pw,
          ph,
        )
      } else {
        wallCtx.fillStyle = '#ffffff'
        wallCtx.fillRect(px, py, pw, ph)
      }
      // Tint walls only; preserve sprite alpha/details via source-atop (on opaque wall pixels only).
      wallCtx.save()
      wallCtx.globalCompositeOperation = 'source-atop'
      wallCtx.fillStyle = WALL_TINT_COLOR
      wallCtx.fillRect(px, py, pw, ph)
      wallCtx.restore()
    }
  }

  // Smooth darkening overlay driven by per-side "clear progress".
  // Draw this BEFORE the pacman/ghost lights so the overlay doesn't dim the light itself.
  if (leftClearProg > 0.0001 || rightClearProg > 0.0001) {
    const D = SIDE_CLEAR_SEAM_FALLOFF_TILES
    const leftRects = wallRects.filter((r) => r.tileX < splitX)
    const rightRects = wallRects.filter((r) => r.tileX >= splitX)

    const drawSide = (
      side: 'left' | 'right',
      amt: number,
      rects: typeof wallRects,
    ) => {
      if (amt <= 0.0001 || rects.length === 0) return

      // If both sides are (partially) darkened, make the center seam less bright/darker.
      // Near-seam darkness depends on the smaller of the two side progress values.
      const otherAmt = side === 'left' ? rightClearProg : leftClearProg
      const nearAmt = Math.min(amt, otherAmt)

      const farAlpha = SIDE_CLEAR_DARK_MAX * amt
      const nearAlpha =
        SIDE_CLEAR_DARK_MIN_NEAR_SEAM * amt +
        (SIDE_CLEAR_DARK_MAX - SIDE_CLEAR_DARK_MIN_NEAR_SEAM) * nearAmt

      wallCtx.save()
      wallCtx.beginPath()
      for (const r of rects) wallCtx.rect(r.px, r.py, r.pw, r.ph)
      wallCtx.clip()

      wallCtx.globalCompositeOperation = 'source-atop'

      if (side === 'left') {
        const nearCenterX = offsetX + (splitX - 0.5) * tileSize
        const farCenterX = offsetX + (splitX - D - 0.5) * tileSize
        const grad = wallCtx.createLinearGradient(farCenterX, 0, nearCenterX, 0)
        grad.addColorStop(0, `rgba(${WALL_DARK_TINT_RGB}, ${farAlpha})`)
        grad.addColorStop(1, `rgba(${WALL_DARK_TINT_RGB}, ${nearAlpha})`)
        wallCtx.fillStyle = grad
      } else {
        const nearCenterX = offsetX + (splitX + 0.5) * tileSize
        const farCenterX = offsetX + (splitX + D + 0.5) * tileSize
        const grad = wallCtx.createLinearGradient(nearCenterX, 0, farCenterX, 0)
        grad.addColorStop(0, `rgba(${WALL_DARK_TINT_RGB}, ${nearAlpha})`)
        grad.addColorStop(1, `rgba(${WALL_DARK_TINT_RGB}, ${farAlpha})`)
        wallCtx.fillStyle = grad
      }

      wallCtx.fillRect(0, 0, w, h)
      wallCtx.restore()
    }

    drawSide('left', leftClearProg, leftRects)
    drawSide('right', rightClearProg, rightRects)
  }

  if (wallRects.length > 0) {
    ctx.drawImage(wallCanvas, 0, 0)
  }

  // Wall lights: build on a scratch layer, then mask to wall alpha (line shapes) so gradients
  // don't flood the full wall tile rectangles.
  if (wallRects.length > 0) {
    const radiusPx = tileSize * PACLIGHT_RADIUS_TILES
    const lightCanvas = ensureScratchCanvas(lightScratchRef, w, h)
    const lctx = lightCanvas.getContext('2d')!
    lctx.clearRect(0, 0, w, h)
    lctx.save()
    lctx.beginPath()
    for (const r of wallRects) lctx.rect(r.px, r.py, r.pw, r.ph)
    lctx.clip()
    lctx.globalCompositeOperation = 'screen'

    // Pac light
    {
      for (const p of pacRenderPositions) {
        const grad = lctx.createRadialGradient(
          offsetX + p.x * tileSize,
          offsetY + p.y * tileSize,
          0,
          offsetX + p.x * tileSize,
          offsetY + p.y * tileSize,
          radiusPx,
        )
        addRadialGradientEasedStops({
          grad,
          colorPrefix: `rgba(${PACLIGHT_COLOR}, `,
          maxAlpha: PACLIGHT_MAX_ALPHA,
          easingExp: LIGHT_RADIAL_EASING_EXPONENT,
        })
        lctx.fillStyle = grad
        lctx.fillRect(0, 0, w, h)
      }
    }

    // Ghost lights (wall-masked)
    const ghostRadiusPx = tileSize * GHOST_LIGHT_RADIUS_TILES
    for (let gi = 0; gi < state.ghosts.length; gi++) {
      const g = state.ghosts[gi]
      if (g.isIncapacitated) continue
      const ga = ghostAnims[gi]
      const gx = ga ? lerp(ga.from.x, ga.to.x, ga.t) : g.position.x
      const gy = ga ? lerp(ga.from.y, ga.to.y, ga.t) : g.position.y
      const ghostCenterX = gx + 0.5
      const ghostCenterY = gy + 0.5

      const ghostRenderPositions: Array<{ x: number; y: number }> = [
        { x: gx, y: gy },
      ]

      if (ghostCenterX <= ENTITY_DUP_THRESHOLD_TILES) {
        ghostRenderPositions.push({ x: gx + bw, y: gy })
      } else if (ghostCenterX >= bw - ENTITY_DUP_THRESHOLD_TILES) {
        ghostRenderPositions.push({ x: gx - bw, y: gy })
      }

      if (ghostCenterY <= ENTITY_DUP_THRESHOLD_TILES) {
        ghostRenderPositions.push({ x: gx, y: gy + bh })
      } else if (ghostCenterY >= bh - ENTITY_DUP_THRESHOLD_TILES) {
        ghostRenderPositions.push({ x: gx, y: gy - bh })
      }

      const ghostColor = ghostVisualColor(g, state)
      const rgb = hexToRgb(ghostColor)

      for (const p of ghostRenderPositions) {
        const gPx = offsetX + p.x * tileSize + tileSize / 2
        const gPy = offsetY + p.y * tileSize + tileSize / 2
        const grad = lctx.createRadialGradient(
          gPx,
          gPy,
          0,
          gPx,
          gPy,
          ghostRadiusPx,
        )
        addRadialGradientEasedStops({
          grad,
          colorPrefix: `rgba(${rgb.r},${rgb.g},${rgb.b}, `,
          maxAlpha: GHOST_LIGHT_ALPHA,
          easingExp: LIGHT_RADIAL_EASING_EXPONENT,
        })
        lctx.fillStyle = grad
        lctx.fillRect(0, 0, w, h)
      }
    }

    lctx.restore()

    lctx.globalCompositeOperation = 'destination-in'
    lctx.drawImage(wallCanvas, 0, 0)
    lctx.globalCompositeOperation = 'source-over'

    ctx.save()
    ctx.globalCompositeOperation = 'screen'
    ctx.drawImage(lightCanvas, 0, 0)
    ctx.restore()
  }

  for (let y = 0; y < bh; y++) {
    for (let x = 0; x < bw; x++) {
      const tile = tileType(x, y, state)
      const px = xEdges[x]
      const py = yEdges[y]
      const pw = xEdges[x + 1] - xEdges[x]
      const ph = yEdges[y + 1] - yEdges[y]
      if (tile === Tile.Exit) {
        if (sprites) ctx.drawImage(sprites.exit, px, py, pw, ph)
        continue
      }
      if (tile === Tile.PowerPellet) {
        const cx = px + pw / 2
        const cy = py + ph / 2
        ctx.save()
        ctx.fillStyle = 'rgba(251, 191, 36, 0.95)' // warm yellow
        ctx.shadowColor = 'rgba(251, 191, 36, 0.9)'
        ctx.shadowBlur = Math.min(pw, ph) * 0.18
        ctx.beginPath()
        ctx.arc(cx, cy, Math.min(pw, ph) * 0.23, 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
        continue
      }
      if (tile === Tile.Pellet) {
        if (sprites) {
          ctx.drawImage(sprites.pellet, px, py, pw, ph)
        } else {
          const cx = px + pw / 2
          const cy = py + ph / 2
          ctx.fillStyle = '#ffffff'
          ctx.beginPath()
          ctx.arc(cx, cy, Math.min(pw, ph) * 0.11, 0, Math.PI * 2)
          ctx.fill()
        }
        continue
      }
      // Ghost-house tiles are intentionally invisible during gameplay.
    }
  }

  const drawFruitAt = (fx: number, fy: number) => {
    const cx = offsetX + fx * tileSize + tileSize / 2
    const cy = offsetY + fy * tileSize + tileSize / 2
    ctx.save()
    ctx.shadowColor = '#f97316'
    ctx.shadowBlur = tileSize * 0.5
    ctx.fillStyle = '#f97316'
    ctx.beginPath()
    ctx.arc(cx, cy, tileSize * 0.22, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()
  }
  if (state.fruitActiveLeft) {
    const p = fruitPos('left')
    drawFruitAt(p.x, p.y)
  }
  if (state.fruitActiveRight) {
    const p = fruitPos('right')
    drawFruitAt(p.x, p.y)
  }

  // Hide Pac/ghost bodies outside the visible board during warp transitions.
  ctx.save()
  ctx.beginPath()
  ctx.rect(offsetX, offsetY, bw * tileSize, bh * tileSize)
  ctx.clip()

  for (const p of pacRenderPositions) {
    const pacCx = offsetX + p.x * tileSize
    const pacCy = offsetY + p.y * tileSize
    ctx.save()
    ctx.shadowColor = '#fde047'
    ctx.shadowBlur = tileSize * 0.7
    ctx.fillStyle = '#facc15'
    ctx.beginPath()
    ctx.arc(pacCx, pacCy, tileSize * 0.35, 0, Math.PI * 2)
    ctx.fill()
    ctx.restore()
  }

  for (let gi = 0; gi < state.ghosts.length; gi++) {
    const g = state.ghosts[gi]
    const ga = ghostAnims[gi]
    const gx = ga ? lerp(ga.from.x, ga.to.x, ga.t) : g.position.x
    const gy = ga ? lerp(ga.from.y, ga.to.y, ga.t) : g.position.y
    const ghostCenterX = gx + 0.5
    const ghostCenterY = gy + 0.5

    const ghostRenderPositions: Array<{ x: number; y: number }> = [
      { x: gx, y: gy },
    ]

    if (ghostCenterX <= ENTITY_DUP_THRESHOLD_TILES) {
      ghostRenderPositions.push({ x: gx + bw, y: gy })
    } else if (ghostCenterX >= bw - ENTITY_DUP_THRESHOLD_TILES) {
      ghostRenderPositions.push({ x: gx - bw, y: gy })
    }

    if (ghostCenterY <= ENTITY_DUP_THRESHOLD_TILES) {
      ghostRenderPositions.push({ x: gx, y: gy + bh })
    } else if (ghostCenterY >= bh - ENTITY_DUP_THRESHOLD_TILES) {
      ghostRenderPositions.push({ x: gx, y: gy - bh })
    }

    for (const p of ghostRenderPositions) {
      const cx = offsetX + p.x * tileSize + tileSize / 2
      const cy = offsetY + p.y * tileSize + tileSize / 2
      const r = tileSize * 0.32
      if (g.isIncapacitated) {
        // Eyes only
        const eyeR = r * 0.22
        ctx.save()
        ctx.fillStyle = '#ffffff'
        ctx.beginPath()
        ctx.arc(cx - r * 0.35, cy - r * 0.1, eyeR, 0, Math.PI * 2)
        ctx.arc(cx + r * 0.35, cy - r * 0.1, eyeR, 0, Math.PI * 2)
        ctx.fill()
        ctx.restore()
      } else {
        const bodyColor = ghostVisualColor(g, state)
        ctx.save()
        ctx.shadowColor = bodyColor
        ctx.shadowBlur = tileSize * 0.5
        ctx.fillStyle = bodyColor
        ctx.beginPath()
        ctx.arc(cx, cy - r * 0.15, r, Math.PI, 0)
        ctx.lineTo(cx + r, cy + r * 0.8)
        ctx.lineTo(cx - r, cy + r * 0.8)
        ctx.closePath()
        ctx.fill()
        ctx.restore()
        ctx.fillStyle = '#0b1020'
        ctx.beginPath()
        ctx.arc(cx - r * 0.35, cy - r * 0.1, r * 0.16, 0, Math.PI * 2)
        ctx.arc(cx + r * 0.35, cy - r * 0.1, r * 0.16, 0, Math.PI * 2)
        ctx.fill()
      }
    }
  }

  ctx.restore() // entity clip

  // Fruit-side refresh flash overlay.
  // Triggered when one side is refilled after collecting a fruit.
  const leftFlashP = Math.min(
    1,
    state.leftSideFruitFlashMs / FRUIT_SIDE_FLASH_DURATION_MS,
  )
  const rightFlashP = Math.min(
    1,
    state.rightSideFruitFlashMs / FRUIT_SIDE_FLASH_DURATION_MS,
  )
  if (leftFlashP > 0) {
    const alpha =
      FRUIT_SIDE_FLASH_MAX_ALPHA * Math.pow(leftFlashP, FRUIT_SIDE_FLASH_FADE_POW)
    ctx.save()
    ctx.globalCompositeOperation = 'source-over'
    ctx.fillStyle = `rgba(255,255,255,${alpha})`
    ctx.fillRect(offsetX, offsetY, splitX * tileSize, bh * tileSize)
    ctx.restore()
  }
  if (rightFlashP > 0) {
    const alpha =
      FRUIT_SIDE_FLASH_MAX_ALPHA * Math.pow(rightFlashP, FRUIT_SIDE_FLASH_FADE_POW)
    ctx.save()
    ctx.globalCompositeOperation = 'source-over'
    ctx.fillStyle = `rgba(255,255,255,${alpha})`
    ctx.fillRect(
      offsetX + splitX * tileSize,
      offsetY,
      (bw - splitX) * tileSize,
      bh * tileSize,
    )
    ctx.restore()
  }

  drawHudBar(ctx, w, margin, state)

  if (state.isGameOver) {
    drawGameOverOverlay(ctx, w, h)
  }

}
