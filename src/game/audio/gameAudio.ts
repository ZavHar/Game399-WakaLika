import { Howl } from 'howler'

import fruitUrl from '../../assets/audio/fruit.mp3?url'
import gameOverUrl from '../../assets/audio/game_over.mp3?url'
import ghostEatenUrl from '../../assets/audio/ghost_eaten.mp3?url'
import lowTimeWarningUrl from '../../assets/audio/low_time_warning.mp3?url'
import musicUrl from '../../assets/audio/music_loop.mp3?url'
import pelletUrl from '../../assets/audio/pellet.mp3?url'
import powerPelletUrl from '../../assets/audio/power_pellet.mp3?url'

import type { CollisionSfx, PelletSfx } from './sfxTypes'

const LOW_TIME_WARNING_SEC = 10

export type GameAudio = {
  /** Call once after first user gesture (keyboard / pointer) so the browser allows audio. */
  tryStartMusic: () => void
  stopMusic: () => void
  playPelletSfx: (sfx: PelletSfx) => void
  playCollisionSfx: (sfx: CollisionSfx) => void
  /** When countdown crosses into last N seconds. */
  maybePlayLowTimeWarning: (prevSec: number, nextSec: number) => void
}

export function createGameAudio(): GameAudio {
  const music = new Howl({
    src: [musicUrl],
    loop: true,
    volume: 0.22,
    html5: true,
  })

  const pellet = new Howl({ src: [pelletUrl], volume: 0.38 })
  const powerPellet = new Howl({ src: [powerPelletUrl], volume: 0.42 })
  const fruit = new Howl({ src: [fruitUrl], volume: 0.45 })
  const ghostEaten = new Howl({ src: [ghostEatenUrl], volume: 0.4 })
  const gameOver = new Howl({ src: [gameOverUrl], volume: 0.5 })
  const lowTimeWarning = new Howl({
    src: [lowTimeWarningUrl],
    volume: 0.35,
  })

  let musicStarted = false

  const tryStartMusic = () => {
    if (musicStarted) return
    if (!music.playing()) {
      music.play()
      musicStarted = true
    }
  }

  const stopMusic = () => {
    music.stop()
    musicStarted = false
  }

  const playPelletSfx = (sfx: PelletSfx) => {
    if (sfx.powerPellet) {
      powerPellet.play()
    } else if (sfx.pellet) {
      pellet.play()
    }
    if (sfx.fruitLeft || sfx.fruitRight) {
      fruit.play()
    }
  }

  const playCollisionSfx = (sfx: CollisionSfx) => {
    if (sfx.ghostEaten) {
      ghostEaten.play()
    }
    if (sfx.gameOver) {
      stopMusic()
      gameOver.play()
    }
  }

  const maybePlayLowTimeWarning = (prevSec: number, nextSec: number) => {
    const prev = Math.floor(prevSec)
    const next = Math.floor(nextSec)
    if (prev > LOW_TIME_WARNING_SEC && next <= LOW_TIME_WARNING_SEC && next > 0) {
      lowTimeWarning.play()
    }
  }

  return {
    tryStartMusic,
    stopMusic,
    playPelletSfx,
    playCollisionSfx,
    maybePlayLowTimeWarning,
  }
}
