import { useEffect, useRef } from 'react'
import { BUFFERED_DIR_RELEASE_CLEAR_MS } from '../data/constants'
import { canPacStartTurnInDirection } from './pacMan'
import type { Direction, GameState } from '../data/types'

// React's `MutableRefObject` is deprecated in recent React typings.
// `useRef`'s `.current` shape is all we need here.
type MutableRef<T> = { current: T }

const DIRECTION_KEYS: Record<Direction, readonly string[]> = {
  up: ['ArrowUp', 'w'],
  down: ['ArrowDown', 's'],
  left: ['ArrowLeft', 'a'],
  right: ['ArrowRight', 'd'],
}

function keyToDirection(key: string): Direction | null {
  for (const d of Object.keys(DIRECTION_KEYS) as Direction[]) {
    if (DIRECTION_KEYS[d].includes(key)) return d
  }
  return null
}

function isDirectionKeyHeld(dir: Direction, keys: Set<string>): boolean {
  return DIRECTION_KEYS[dir].some((k) => keys.has(k))
}

/** When buffered direction becomes legal (e.g. at an intersection), commit it to desiredDir. */
export function applyBufferedPacDirectionIfValid(
  s: GameState,
  desiredDirRef: MutableRef<Direction>,
  bufferedDirRef: MutableRef<Direction | null>,
  bufferReleaseTimerRef: MutableRef<ReturnType<typeof setTimeout> | null>,
) {
  const b = bufferedDirRef.current
  if (!b) return
  if (!canPacStartTurnInDirection(s, b)) return
  desiredDirRef.current = b
  bufferedDirRef.current = null
  if (bufferReleaseTimerRef.current) {
    clearTimeout(bufferReleaseTimerRef.current)
    bufferReleaseTimerRef.current = null
  }
}

export function usePacmanBufferedInput(args: {
  stateRef: MutableRef<GameState>
  desiredDirRef: MutableRef<Direction>
  bufferedDirRef: MutableRef<Direction | null>
  bufferReleaseTimerRef: MutableRef<ReturnType<typeof setTimeout> | null>
}) {
  const { stateRef, desiredDirRef, bufferedDirRef, bufferReleaseTimerRef } = args
  const keysHeldRef = useRef<Set<string>>(new Set())

  useEffect(() => {
    const keysHeld = keysHeldRef.current
    const clearReleaseTimer = () => {
      if (bufferReleaseTimerRef.current) {
        clearTimeout(bufferReleaseTimerRef.current)
        bufferReleaseTimerRef.current = null
      }
    }

    const scheduleBufferClearIfReleased = (dir: Direction) => {
      if (bufferedDirRef.current !== dir) return
      if (isDirectionKeyHeld(dir, keysHeldRef.current)) return
      clearReleaseTimer()
      bufferReleaseTimerRef.current = setTimeout(() => {
        bufferReleaseTimerRef.current = null
        if (
          bufferedDirRef.current === dir &&
          !isDirectionKeyHeld(dir, keysHeldRef.current)
        ) {
          bufferedDirRef.current = null
        }
      }, BUFFERED_DIR_RELEASE_CLEAR_MS)
    }

    const onKeyDown = (e: KeyboardEvent) => {
      const dir = keyToDirection(e.key)
      if (!dir) return
      if (e.repeat) return

      keysHeldRef.current.add(e.key)
      clearReleaseTimer()

      const s = stateRef.current
      if (canPacStartTurnInDirection(s, dir)) {
        desiredDirRef.current = dir
        bufferedDirRef.current = null
      } else {
        bufferedDirRef.current = dir
      }
    }

    const onKeyUp = (e: KeyboardEvent) => {
      const dir = keyToDirection(e.key)
      if (!dir) return

      keysHeldRef.current.delete(e.key)
      scheduleBufferClearIfReleased(dir)
    }

    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    return () => {
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
      clearReleaseTimer()
      keysHeld.clear()
    }
  }, [stateRef, desiredDirRef, bufferedDirRef, bufferReleaseTimerRef])
}
