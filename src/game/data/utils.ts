import type { Vec2 } from '../board/levels'
import type { Direction } from './types'

export function vecEquals(a: Vec2, b: Vec2) {
  return a.x === b.x && a.y === b.y
}

/** Pac-Man uses float tile coords; ghosts use integer cells. */
export function sameTile(a: Vec2, b: Vec2): boolean {
  return Math.floor(a.x) === Math.floor(b.x) && Math.floor(a.y) === Math.floor(b.y)
}

export function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t
}

export function dirToVec(d: Direction): Vec2 {
  switch (d) {
    case 'up':
      return { x: 0, y: -1 }
    case 'down':
      return { x: 0, y: 1 }
    case 'left':
      return { x: -1, y: 0 }
    case 'right':
      return { x: 1, y: 0 }
  }
}

export function randomChoice<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)]
}

export function isOppositeDir(a: Direction, b: Direction): boolean {
  const va = dirToVec(a)
  const vb = dirToVec(b)
  return va.x === -vb.x && va.y === -vb.y
}

export function oppositeDirection(d: Direction): Direction {
  switch (d) {
    case 'up':
      return 'down'
    case 'down':
      return 'up'
    case 'left':
      return 'right'
    case 'right':
      return 'left'
  }
}

export function distanceSquared(a: Vec2, b: Vec2): number {
  const dx = a.x - b.x
  const dy = a.y - b.y
  return dx * dx + dy * dy
}
