import { useEffect, useRef, useState } from 'react'
import { Link, Route, Routes } from 'react-router-dom'
import {
  advancePacmanContinuous,
  applyBufferedPacDirectionIfValid,
  checkCollisions,
  createInitialState,
  drawGame,
  handlePelletsAndFruit,
  GHOST_TILES_PER_SEC,
  randomWalkableTileExcluding,
  MAX_TILE_STEPS_PER_FRAME,
  PAC_SUBSTEPS_PER_FRAME,
  tryMoveGhostOneTile,
  updateGhostDestinations,
  usePacmanBufferedInput,
  vecEquals,
  Tile,
  type Direction,
  type GameState,
  type TileSlideAnim,
} from './game/data'
import { SIDE_CLEAR_TRANSITION_DURATION_MS } from './game/data/constants'
import { LevelEditorPage } from './editor/LevelEditorPage'
import './App.css'

function GameScene() {
  const stateRef = useRef<GameState>(createInitialState())
  const desiredDirRef = useRef<Direction>(stateRef.current.pacDirection)
  const bufferedDirRef = useRef<Direction | null>(null)
  const bufferReleaseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(
    null,
  )

  usePacmanBufferedInput({
    stateRef,
    desiredDirRef,
    bufferedDirRef,
    bufferReleaseTimerRef,
  })

  const canvasRef = useRef<HTMLCanvasElement | null>(null)
  const ghostMoveAccRef = useRef<number[]>([0, 0, 0, 0])

  const [debugPacPos, setDebugPacPos] = useState(() => ({
    x: stateRef.current.pacPosition.x,
    y: stateRef.current.pacPosition.y,
  }))
  const lastDebugPacPosUpdateMsRef = useRef(0)

  const [showGhostPaths, setShowGhostPaths] = useState(false)
  const showGhostPathsRef = useRef(showGhostPaths)
  useEffect(() => {
    showGhostPathsRef.current = showGhostPaths
  }, [showGhostPaths])

  const ghostAnimRefs = useRef<TileSlideAnim[]>(
    stateRef.current.ghosts.map((g) => ({
      from: { ...g.position },
      to: { ...g.position },
      t: 1,
    })),
  )

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const resize = () => {
      const dpr = Math.max(1, window.devicePixelRatio || 1)
      const rect = canvas.getBoundingClientRect()
      const nextW = Math.max(1, Math.floor(rect.width * dpr))
      const nextH = Math.max(1, Math.floor(rect.height * dpr))
      if (canvas.width !== nextW) canvas.width = nextW
      if (canvas.height !== nextH) canvas.height = nextH
    }

    resize()
    const ro = new ResizeObserver(resize)
    ro.observe(canvas)
    window.addEventListener('resize', resize)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', resize)
    }
  }, [])

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let lastTime = performance.now()
    let timeTickAcc = 0
    let frameId = 0

    const tick = (timeMs: number) => {
      const dt = Math.min((timeMs - lastTime) / 1000, 0.2)
      lastTime = timeMs

      let s = stateRef.current
      if (!s.isGameOver) {
        const subDt = dt / PAC_SUBSTEPS_PER_FRAME
        for (let sub = 0; sub < PAC_SUBSTEPS_PER_FRAME; sub++) {
          applyBufferedPacDirectionIfValid(
            s,
            desiredDirRef,
            bufferedDirRef,
            bufferReleaseTimerRef,
          )
          s = advancePacmanContinuous(s, subDt, desiredDirRef.current)
        }

        // Incapacitated ghost ticking:
        // - double speed
        // - decrement countdown while waiting in ghost house
        const dtMs = dt * 1000
        s = {
          ...s,
          ghosts: s.ghosts.map((g) => {
            const isIncap = !!g.isIncapacitated
            const waitMs =
              isIncap && g.incapacitatedPhase === 'waiting_in_house'
                ? Math.max(0, (g.incapacitatedWaitMs ?? 0) - dtMs)
                : g.incapacitatedWaitMs ?? 0
            return {
              ...g,
              speed: GHOST_TILES_PER_SEC * (isIncap ? 2 : 1),
              incapacitatedWaitMs: waitMs,
            }
          }),
        }

        s = updateGhostDestinations(s)
        const bw = s.leftHalf.width + s.rightHalf.width
        const bh = s.leftHalf.height
        const adjustWrappedToAdj = (from: number, to: number, span: number) => {
          const d = to - from
          if (d > span / 2) return to - span
          if (d < -span / 2) return to + span
          return to
        }

        for (let i = 0; i < s.ghosts.length; i++) {
          ghostMoveAccRef.current[i] =
            (ghostMoveAccRef.current[i] ?? 0) + s.ghosts[i].speed * dt
        }
        for (let i = 0; i < s.ghosts.length; i++) {
          let gSteps = 0
          while (
            (ghostMoveAccRef.current[i] ?? 0) >= 1 &&
            gSteps < MAX_TILE_STEPS_PER_FRAME
          ) {
            const prevG = { ...s.ghosts[i].position }
            const nextState = tryMoveGhostOneTile(s, i)
            if (!vecEquals(prevG, nextState.ghosts[i].position)) {
              ghostMoveAccRef.current[i]! -= 1
              s = nextState

              const nextPos = s.ghosts[i]!.position
              const toAdj = {
                x: adjustWrappedToAdj(prevG.x, nextPos.x, bw),
                y: adjustWrappedToAdj(prevG.y, nextPos.y, bh),
              }
              ghostAnimRefs.current[i] = {
                from: prevG,
                to: toAdj,
                t: ghostMoveAccRef.current[i]!,
              }
              gSteps++
            } else {
              ghostMoveAccRef.current[i] = Math.min(
                ghostMoveAccRef.current[i] ?? 0,
                1,
              )
              break
            }
          }
        }

        for (let i = 0; i < s.ghosts.length; i++) {
          const g = ghostAnimRefs.current[i]
          if (g) {
            ghostAnimRefs.current[i] = {
              ...g,
              t: Math.min(1, ghostMoveAccRef.current[i] ?? 0),
            }
          }
        }

        s = handlePelletsAndFruit(s)
        // Smoothly transition the wall tint when each side becomes fully cleared.
        const leftTarget = s.pelletsLeftLeft === 0
        const rightTarget = s.pelletsLeftRight === 0
        const transitionSeconds = SIDE_CLEAR_TRANSITION_DURATION_MS / 1000
        const stepToward = (cur: number, target: boolean) => {
          if (transitionSeconds <= 0) return target ? 1 : 0
          const dir = target ? 1 : -1
          const next = cur + dir * (dt / transitionSeconds)
          return Math.max(0, Math.min(1, next))
        }
        s =
          s.isGameOver
            ? s
            : {
                ...s,
                leftSideClearProgress: stepToward(
                  s.leftSideClearProgress,
                  leftTarget,
                ),
                rightSideClearProgress: stepToward(
                  s.rightSideClearProgress,
                  rightTarget,
                ),
              }

        // Fruit refresh flash timers (white overlay).
        s =
          s.isGameOver
            ? s
            : {
                ...s,
                leftSideFruitFlashMs: Math.max(
                  0,
                  s.leftSideFruitFlashMs - dtMs,
                ),
                rightSideFruitFlashMs: Math.max(
                  0,
                  s.rightSideFruitFlashMs - dtMs,
                ),
              }

        // Power pellet fear timer.
        s =
          s.isGameOver
            ? s
            : {
                ...s,
                fearMs: Math.max(0, s.fearMs - dtMs),
              }
        s = checkCollisions(s, ghostAnimRefs.current)

        if (!s.isGameOver) {
          timeTickAcc += dt
          while (timeTickAcc >= 1) {
            timeTickAcc -= 1
            const nextT = s.timeRemaining - 1
            s = { ...s, timeRemaining: Math.max(0, nextT) }
            if (nextT <= 0) {
              s = { ...s, isGameOver: true }
              break
            }
          }
        }
      }

      stateRef.current = s

      // Throttle React updates: we only need this for a small debug overlay.
      if (timeMs - lastDebugPacPosUpdateMsRef.current > 100) {
        lastDebugPacPosUpdateMsRef.current = timeMs
        setDebugPacPos({ x: s.pacPosition.x, y: s.pacPosition.y })
      }
      drawGame(ctx, canvas, s, ghostAnimRefs.current, {
        showGhostPaths: showGhostPathsRef.current,
      })
      frameId = requestAnimationFrame(tick)
    }

    frameId = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(frameId)
  }, [])

  const collectAllPelletsForTesting = () => {
    const s = stateRef.current
    const clearHalf = (half: GameState['leftHalf']): GameState['leftHalf'] => ({
      ...half,
      tiles: half.tiles.map((row) =>
        row.map((t) =>
          t === Tile.Pellet || t === Tile.PowerPellet ? Tile.Empty : t,
        ),
      ),
    })
    stateRef.current = {
      ...s,
      leftHalf: clearHalf(s.leftHalf),
      rightHalf: clearHalf(s.rightHalf),
      pelletsLeftLeft: 0,
      pelletsLeftRight: 0,
      leftSideClearProgress: 1,
      rightSideClearProgress: 1,
      leftSideFruitFlashMs: 0,
      rightSideFruitFlashMs: 0,
    }
  }

  const incapacitateAllGhostsForTesting = () => {
    const s = stateRef.current
    stateRef.current = {
      ...s,
      ghosts: s.ghosts.map((g) => ({
        ...g,
        isIncapacitated: true,
        incapacitatedPhase: 'roam',
        incapacitatedRoamsLeft: 3,
        incapacitatedWaitMs: 0,
        destination: randomWalkableTileExcluding(s, g.position),
      })),
    }
  }

  return (
    <>
      <canvas ref={canvasRef} className="gameCanvas" />
      <div className="debugControls">
        <div className="debugControlsTitle">Debug Controls</div>
        <div className="debugControlsButtons">
          <button
            className="testButton"
            onClick={() => setShowGhostPaths((v) => !v)}
            type="button"
          >
            Ghost Paths: {showGhostPaths ? 'On' : 'Off'}
          </button>
          <button
            className="testButton"
            onClick={collectAllPelletsForTesting}
            type="button"
          >
            Collect All Pellets
          </button>
          <button
            className="testButton"
            onClick={incapacitateAllGhostsForTesting}
            type="button"
          >
            Incapacitate Ghosts
          </button>
        <hr className="debugControlsDivider" />
        <div className="debugControlsPos">
          Player Pos: {debugPacPos.x.toFixed(2)}, {debugPacPos.y.toFixed(2)}
        </div>
        </div>
      </div>
    </>
  )
}

function App() {
  return (
    <main className="app">
      <header className="topbar">
        <nav className="topbarNav">
          <Link className="topbarLink" to="/">
            Play
          </Link>
          <Link className="topbarLink" to="/editor">
            Editor
          </Link>
        </nav>
      </header>
      <Routes>
        <Route
          path="/"
          element={
            <>
              <GameScene />
              <div className="controls-hint">WASD / Arrow keys to move</div>
            </>
          }
        />
        <Route path="/editor" element={<LevelEditorPage />} />
      </Routes>
    </main>
  )
}

export default App
