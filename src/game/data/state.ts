import {
  flipLevelHalfHorizontally,
  HALF_LAYOUTS,
  Tile,
  type Vec2,
} from '../board/levels'
import { GHOST_TILES_PER_SEC, LEVEL_DURATION } from './constants'
import { countPellets } from '../board/grid'
import { PAC_SPAWN } from '../board/spawns'
import { updateGhostDestinations } from '../ghosts/ghostAi'
import type { GameState, Ghost } from './types'
import { randomChoice } from './utils'

function collectGhostHouseTiles(leftHalf: GameState['leftHalf'], rightHalf: GameState['rightHalf']): Vec2[] {
  const out: Vec2[] = []
  const leftW = leftHalf.width
  const fullW = leftHalf.width + rightHalf.width
  const h = leftHalf.height
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < fullW; x++) {
      const t = x < leftW ? leftHalf.tiles[y]![x]! : rightHalf.tiles[y]![x - leftW]!
      if (t === Tile.GhostHouse) out.push({ x, y })
    }
  }
  return out
}

function pickGhostSpawnsRandom(
  leftHalf: GameState['leftHalf'],
  rightHalf: GameState['rightHalf'],
  n: number,
): Vec2[] {
  const tiles = collectGhostHouseTiles(leftHalf, rightHalf)
  if (tiles.length === 0) {
    return Array.from({ length: n }, () => ({ ...PAC_SPAWN }))
  }
  const bag = [...tiles]
  for (let i = bag.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    const t = bag[i]!
    bag[i] = bag[j]!
    bag[j] = t
  }
  const out: Vec2[] = []
  for (let i = 0; i < n; i++) out.push({ ...bag[i % bag.length]! })
  return out
}

export function createInitialState(): GameState {
  const leftHalf = randomChoice(HALF_LAYOUTS)
  const rightHalf = flipLevelHalfHorizontally(randomChoice(HALF_LAYOUTS))
  const pacPosition = {
    x: PAC_SPAWN.x + 0.5,
    y: PAC_SPAWN.y + 0.5,
  }
  const ghostSpawnTiles = pickGhostSpawnsRandom(leftHalf, rightHalf, 4)

  const ghostsBase: Ghost[] = [
    {
      id: 'red',
      position: { ...ghostSpawnTiles[0]! },
      destination: { x: 0, y: 0 },
      direction: 'left',
      speed: GHOST_TILES_PER_SEC,
      isIncapacitated: false,
      incapacitatedPhase: undefined,
      incapacitatedRoamsLeft: 0,
      incapacitatedWaitMs: 0,
    },
    {
      id: 'pink',
      position: { ...ghostSpawnTiles[1]! },
      destination: { x: 0, y: 0 },
      direction: 'right',
      speed: GHOST_TILES_PER_SEC,
      isIncapacitated: false,
      incapacitatedPhase: undefined,
      incapacitatedRoamsLeft: 0,
      incapacitatedWaitMs: 0,
    },
    {
      id: 'blue',
      position: { ...ghostSpawnTiles[2]! },
      destination: { x: 0, y: 0 },
      direction: 'left',
      speed: GHOST_TILES_PER_SEC,
      isIncapacitated: false,
      incapacitatedPhase: undefined,
      incapacitatedRoamsLeft: 0,
      incapacitatedWaitMs: 0,
    },
    {
      id: 'orange',
      position: { ...ghostSpawnTiles[3]! },
      destination: { x: 0, y: 0 },
      direction: 'right',
      speed: GHOST_TILES_PER_SEC,
      isScattering: false,
      isIncapacitated: false,
      incapacitatedPhase: undefined,
      incapacitatedRoamsLeft: 0,
      incapacitatedWaitMs: 0,
    },
  ]

  const pelletsLeftLeft = countPellets(leftHalf)
  const pelletsLeftRight = countPellets(rightHalf)
  const leftInitCleared = pelletsLeftLeft === 0
  const rightInitCleared = pelletsLeftRight === 0

  const shell: GameState = {
    leftHalf,
    rightHalf,
    pacPosition,
    pacDirection: 'left',
    fearMs: 0,
    pacWarpOffsetX: 0,
    pacWarpOffsetY: 0,
    ghosts: ghostsBase,
    pelletsLeftLeft,
    pelletsLeftRight,
    fruitActiveLeft: false,
    fruitActiveRight: false,
    leftSideClearProgress: leftInitCleared ? 1 : 0,
    rightSideClearProgress: rightInitCleared ? 1 : 0,
    leftSideFruitFlashMs: 0,
    rightSideFruitFlashMs: 0,
    score: 0,
    timeRemaining: LEVEL_DURATION,
    level: 1,
    isGameOver: false,
  }

  const ghosts = updateGhostDestinations(shell).ghosts

  return {
    leftHalf,
    rightHalf,
    pacPosition,
    pacDirection: 'left',
    fearMs: 0,
    pacWarpOffsetX: 0,
    pacWarpOffsetY: 0,
    ghosts,
    pelletsLeftLeft: shell.pelletsLeftLeft,
    pelletsLeftRight: shell.pelletsLeftRight,
    fruitActiveLeft: false,
    fruitActiveRight: false,
    leftSideClearProgress: shell.leftSideClearProgress,
    rightSideClearProgress: shell.rightSideClearProgress,
    leftSideFruitFlashMs: 0,
    rightSideFruitFlashMs: 0,
    score: 0,
    timeRemaining: LEVEL_DURATION,
    level: 1,
    isGameOver: false,
  }
}
