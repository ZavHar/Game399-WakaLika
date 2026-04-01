/** One-frame sound triggers produced by game logic (consumed by Howler in App). */
export type PelletSfx = {
  pellet?: boolean
  powerPellet?: boolean
  fruitLeft?: boolean
  fruitRight?: boolean
}

export type CollisionSfx = {
  ghostEaten?: boolean
  gameOver?: boolean
}
