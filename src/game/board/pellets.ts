import {
  flipLevelHalfHorizontally,
  HALF_LAYOUTS,
  Tile,
} from './levels'
import {
  FRUIT_SCORE,
  PELLET_SCORE,
  FRUIT_SIDE_FLASH_DURATION_MS,
  FEAR_DURATION_MS,
} from '../data/constants'
import { countPellets, setTileType, tileType } from './grid'
import { canCollectPelletOrFruitAtPosition } from '../player/pacMan'
import { LEFT_FRUIT_SPAWN_LOCAL, mirroredRightGlobalX } from './spawns'
import type { GameState } from '../data/types'
import { oppositeDirection, randomChoice } from '../data/utils'

function fruitPosForSide(state: GameState, side: 'left' | 'right') {
  if (side === 'left') {
    return {
      x: LEFT_FRUIT_SPAWN_LOCAL.x,
      y: LEFT_FRUIT_SPAWN_LOCAL.y,
    }
  }
  const baseX = state.leftHalf.width
  return {
    x: mirroredRightGlobalX(LEFT_FRUIT_SPAWN_LOCAL.x, baseX),
    y: LEFT_FRUIT_SPAWN_LOCAL.y,
  }
}

function syncFruitActives(state: GameState): GameState {
  // Fruit appears on opposite side of a cleared half:
  // left cleared -> fruit on right, right cleared -> fruit on left.
  return {
    ...state,
    fruitActiveLeft: state.pelletsLeftRight === 0,
    fruitActiveRight: state.pelletsLeftLeft === 0,
  }
}

export function handlePelletsAndFruit(state: GameState): GameState {
  let s = state
  const pos = s.pacPosition
  const gx = Math.floor(pos.x)
  const gy = Math.floor(pos.y)
  const t = tileType(gx, gy, s)

  const leftWidth = s.leftHalf.width
  const isLeftSide = gx < leftWidth
  const isRightSide = gx >= leftWidth

  if (
    (t === Tile.Pellet || t === Tile.PowerPellet) &&
    canCollectPelletOrFruitAtPosition(pos)
  ) {
    s = setTileType(gx, gy, s, Tile.Empty)
    s = {
      ...s,
      score: s.score + PELLET_SCORE,
      pelletsLeftLeft: isLeftSide
        ? s.pelletsLeftLeft - 1
        : s.pelletsLeftLeft,
      pelletsLeftRight: isRightSide
        ? s.pelletsLeftRight - 1
        : s.pelletsLeftRight,
    }

    if (t === Tile.PowerPellet) {
      // Start fear mode: 10s, immediate 180° turn for all ghosts.
      s = {
        ...s,
        fearMs: FEAR_DURATION_MS,
        ghosts: s.ghosts.map((g) => ({
          ...g,
          direction: oppositeDirection(g.direction),
        })),
      }
    }
  }

  s = syncFruitActives(s)

  const canCollectFruit = canCollectPelletOrFruitAtPosition(pos)
  const pacTileX = Math.floor(pos.x)
  const pacTileY = Math.floor(pos.y)
  const leftFruit = fruitPosForSide(s, 'left')
  const rightFruit = fruitPosForSide(s, 'right')

  if (
    canCollectFruit &&
    s.fruitActiveLeft &&
    pacTileX === leftFruit.x &&
    pacTileY === leftFruit.y
  ) {
    // Left fruit corresponds to right side being cleared; refill right side.
    const next = flipLevelHalfHorizontally(randomChoice(HALF_LAYOUTS))
    s = {
      ...s,
      rightHalf: next,
      pelletsLeftRight: countPellets(next),
      score: s.score + FRUIT_SCORE,
      fruitActiveLeft: false,
      rightSideFruitFlashMs: FRUIT_SIDE_FLASH_DURATION_MS,
    }
  } else if (
    canCollectFruit &&
    s.fruitActiveRight &&
    pacTileX === rightFruit.x &&
    pacTileY === rightFruit.y
  ) {
    // Right fruit corresponds to left side being cleared; refill left side.
    const next = randomChoice(HALF_LAYOUTS)
    s = {
      ...s,
      leftHalf: next,
      pelletsLeftLeft: countPellets(next),
      score: s.score + FRUIT_SCORE,
      fruitActiveRight: false,
      leftSideFruitFlashMs: FRUIT_SIDE_FLASH_DURATION_MS,
    }
  }

  // Re-sync in same tick: supports both fruits visible when both halves are cleared.
  s = syncFruitActives(s)

  return s
}
