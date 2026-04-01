import { PAC_GHOST_COLLISION_RADIUS } from '../data/constants'
import type { CollisionSfx } from '../audio/sfxTypes'
import type { GameState, TileSlideAnim } from '../data/types'
import { lerp } from '../data/utils'
import { randomWalkableTileExcluding } from '../ghosts/pathfinding'

/**
 * Same tile-space center as `renderCanvas` ghost draw: lerp between cells, then +0.5 for center.
 * Using only `g.position` would snap to the destination tile as soon as a move starts, so hits
 * would register before the sprite reaches the player.
 */
function ghostVisualCenterInTileSpace(
  g: GameState['ghosts'][0],
  anim: TileSlideAnim | undefined,
): { x: number; y: number } {
  if (anim) {
    const gx = lerp(anim.from.x, anim.to.x, anim.t)
    const gy = lerp(anim.from.y, anim.to.y, anim.t)
    return { x: gx + 0.5, y: gy + 0.5 }
  }
  return { x: g.position.x + 0.5, y: g.position.y + 0.5 }
}

/**
 * @param ghostAnims — Per-frame slide animation (must match rendering). Pass from `ghostAnimRefs` in the game loop.
 */
export function checkCollisions(
  state: GameState,
  ghostAnims?: readonly TileSlideAnim[] | null,
): { state: GameState; sfx: CollisionSfx } {
  const r = PAC_GHOST_COLLISION_RADIUS
  const r2 = r * r
  const { x: px, y: py } = state.pacPosition
  const bw = state.leftHalf.width + state.rightHalf.width
  const bh = state.leftHalf.height

  const wrapCoord = (val: number, size: number) =>
    ((val % size) + size) % size

  for (let i = 0; i < state.ghosts.length; i++) {
    const g = state.ghosts[i]
    if (g.isIncapacitated) continue
    const anim = ghostAnims?.[i]
    const c = ghostVisualCenterInTileSpace(g, anim)

    // Collision distance on a torus: choose the shortest wrapped delta.
    const cx = wrapCoord(c.x, bw)
    const cy = wrapCoord(c.y, bh)
    const dxRaw = Math.abs(px - cx)
    const dyRaw = Math.abs(py - cy)
    const dx = Math.min(dxRaw, bw - dxRaw)
    const dy = Math.min(dyRaw, bh - dyRaw)

    if (dx * dx + dy * dy <= r2) {
      if (state.fearMs > 0) {
        // Power-pellet: Pacman "eats" the ghost instead of losing.
        return {
          state: {
            ...state,
            ghosts: state.ghosts.map((gg, gi) => {
              if (gi !== i) return gg
              return {
                ...gg,
                isIncapacitated: true,
                incapacitatedPhase: 'roam',
                incapacitatedRoamsLeft: 3,
                incapacitatedWaitMs: 0,
                // Give the incapacitated AI a valid starting destination.
                destination: randomWalkableTileExcluding(state, gg.position),
              }
            }),
          },
          sfx: { ghostEaten: true },
        }
      }
      return { state: { ...state, isGameOver: true }, sfx: { gameOver: true } }
    }
  }
  return { state, sfx: {} }
}
