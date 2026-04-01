import type { GameState } from '../data/types'

/** Top bar: score, time, level */
export function drawHudBar(
  ctx: CanvasRenderingContext2D,
  w: number,
  margin: number,
  state: GameState,
) {
  ctx.save()
  ctx.font = `${Math.floor(14 * (window.devicePixelRatio || 1))}px system-ui`
  ctx.fillStyle = '#e5e7eb'
  ctx.textBaseline = 'top'
  ctx.textAlign = 'left'
  ctx.fillText(`Score: ${state.score}`, margin, margin * 0.3)
  ctx.textAlign = 'center'
  ctx.fillText(
    `Time: ${Math.max(0, Math.floor(state.timeRemaining))}s`,
    w / 2,
    margin * 0.3,
  )
  ctx.textAlign = 'right'
  ctx.fillText(`Level: ${state.level}`, w - margin, margin * 0.3)
  ctx.restore()
}

export function drawGameOverOverlay(
  ctx: CanvasRenderingContext2D,
  w: number,
  h: number,
) {
  ctx.fillStyle = 'rgba(2,6,23,0.78)'
  ctx.fillRect(0, 0, w, h)
  ctx.fillStyle = '#f97373'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.font = `${Math.floor(30 * (window.devicePixelRatio || 1))}px system-ui`
  ctx.fillText('Game Over', w / 2, h / 2 - 18)
  ctx.fillStyle = '#e5e7eb'
  ctx.font = `${Math.floor(14 * (window.devicePixelRatio || 1))}px system-ui`
  ctx.fillText('Refresh to restart', w / 2, h / 2 + 16)
}
