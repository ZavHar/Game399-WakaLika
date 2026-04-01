import type { LevelHalf, Vec2 } from '../board/levels'

export type Direction = 'up' | 'down' | 'left' | 'right'

export interface Ghost {
  id: 'red' | 'pink' | 'blue' | 'orange'
  position: Vec2
  /** Integer tile to pathfind toward; new random tile when reached. */
  destination: Vec2
  direction: Direction
  speed: number
  /** Used by orange ghost to keep a stable scatter target. */
  isScattering?: boolean

  /** When incapacitated: fast, harmless, eyes-only, special targeting rules. */
  isIncapacitated?: boolean
  incapacitatedPhase?: 'roam' | 'return_to_house' | 'waiting_in_house'
  incapacitatedRoamsLeft?: number
  incapacitatedWaitMs?: number
}

export interface GameState {
  leftHalf: LevelHalf
  rightHalf: LevelHalf
  pacPosition: Vec2
  pacDirection: Direction
  ghosts: Ghost[]
  /** ms remaining while ghosts are in "fear" mode (power pellet). */
  fearMs: number
  /** Extra copy index for Pac rendering during warp. */
  pacWarpOffsetX: number
  pacWarpOffsetY: number
  pelletsLeftLeft: number
  pelletsLeftRight: number
  fruitActiveLeft: boolean
  fruitActiveRight: boolean
  /** 0..1 interpolation of the "left side cleared" wall tint. */
  leftSideClearProgress: number
  /** 0..1 interpolation of the "right side cleared" wall tint. */
  rightSideClearProgress: number
  /** ms remaining for a white flash overlay on the left side (fruit refresh). */
  leftSideFruitFlashMs: number
  /** ms remaining for a white flash overlay on the right side (fruit refresh). */
  rightSideFruitFlashMs: number
  score: number
  timeRemaining: number
  level: number
  isGameOver: boolean
}

/** Smooth slide between tile centers (ghost visuals). */
export interface TileSlideAnim {
  from: Vec2
  to: Vec2
  t: number
}
