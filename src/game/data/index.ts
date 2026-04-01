/** Game logic & rendering — re-export for convenience. */
export {
  HALF_LAYOUTS,
  HALF_WIDTH,
  LEVEL_HEIGHT,
  LEVEL_WIDTH,
  Tile,
  flipLevelHalfHorizontally,
} from '../board/levels'
export type { LevelHalf, Vec2 } from '../board/levels'
export type { Direction, GameState, Ghost, TileSlideAnim } from './types'
export { PAC_SUBSTEPS_PER_FRAME, MAX_TILE_STEPS_PER_FRAME } from './constants'
export { GHOST_TILES_PER_SEC } from './constants'
export { advancePacmanContinuous } from '../player/pacMan'
export {
  applyBufferedPacDirectionIfValid,
  usePacmanBufferedInput,
} from '../player/input'
export { tryMoveGhostOneTile } from '../ghosts/ghosts'
export { updateGhostDestinations } from '../ghosts/ghostAi'
export { handlePelletsAndFruit } from '../board/pellets'
export { checkCollisions } from '../entities/collision'
export { drawGame } from '../rendering/renderCanvas'
export { createInitialState } from './state'
export { vecEquals } from './utils'
export { randomWalkableTileExcluding } from '../ghosts/pathfinding'
