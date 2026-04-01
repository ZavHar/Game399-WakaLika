import { useEffect, useMemo, useState } from 'react'
import rawGrids from '../game/data/levelGrids.json'
import { LEFT_FRUIT_SPAWN_LOCAL, PAC_SPAWN } from '../game/board/spawns'
import { EditorTile, clampTile, type TileValue } from './editorTypes'
import { LevelGridEditor, type DrawMode } from './LevelGridEditor'
import './levelEditor.css'

type LevelGridsFile = Record<string, number[][]>
type EditorGrids = Record<string, TileValue[][]>

function toTileGrid(grid: number[][]): TileValue[][] {
  return grid.map((row) => row.map((n) => clampTile(n)))
}

function serialize(grid: TileValue[][]): number[][] {
  return grid.map((row) => row.map((n) => n))
}

function cloneGrid(grid: TileValue[][]): TileValue[][] {
  return grid.map((r) => r.slice() as TileValue[])
}

function validate14x36(name: string, grid: TileValue[][]) {
  if (grid.length !== 36) throw new Error(`${name} must have 36 rows`)
  for (let y = 0; y < 36; y++) {
    if (grid[y]!.length !== 14) throw new Error(`${name} row ${y} must have 14 cols`)
    for (let x = 0; x < 14; x++) {
      const v = grid[y]![x]!
      if (v !== 0 && v !== 1 && v !== 2 && v !== 3 && v !== 4 && v !== 5) {
        throw new Error(`${name} has invalid tile`)
      }
    }
  }
}

export function LevelEditorPage() {
  const initial = useMemo(() => rawGrids as LevelGridsFile, [])
  const [layouts, setLayouts] = useState<EditorGrids>(() => {
    const next: EditorGrids = {}
    for (const k of Object.keys(initial)) next[k] = toTileGrid(initial[k]!)
    return next
  })
  const [active, setActive] = useState<string>(() => Object.keys(initial)[0] ?? '')
  const [showDuplicatePopup, setShowDuplicatePopup] = useState(false)
  const [showRenamePopup, setShowRenamePopup] = useState(false)
  const [showDeletePopup, setShowDeletePopup] = useState(false)
  const [duplicateNameInput, setDuplicateNameInput] = useState('')
  const [renameNameInput, setRenameNameInput] = useState('')
  const [tool, setTool] = useState<EditorTile>(EditorTile.Wall)
  const [drawMode, setDrawMode] = useState<DrawMode>('paint')
  const [status, setStatus] = useState<string>('')
  const [isSaving, setIsSaving] = useState(false)

  const layoutNames = useMemo(() => Object.keys(layouts).sort((a, b) => a.localeCompare(b)), [layouts])
  const tiles = layouts[active] ?? []
  const setTiles = (next: TileValue[][]) => {
    setLayouts((prev) => ({ ...prev, [active]: next }))
  }

  const normalizeName = (raw: string) => raw.trim()
  const validateName = (name: string) => /^[A-Za-z0-9_-]+$/.test(name)

  useEffect(() => {
    if (active && !renameNameInput) setRenameNameInput(active)
  }, [active, renameNameInput])

  useEffect(() => {
    const isTypingTarget = (t: EventTarget | null) => {
      const el = t as HTMLElement | null
      if (!el) return false
      if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT') {
        return true
      }
      return el.isContentEditable
    }

    const onKeyDown = (e: KeyboardEvent) => {
      const key = e.key.toLowerCase()
      // Escape should always close popups, even when typing in inputs.
      if (e.key === 'Escape' || e.code === 'Escape') {
        e.preventDefault()
        setShowDuplicatePopup(false)
        setShowRenamePopup(false)
        setShowDeletePopup(false)
        return
      }

      if (isTypingTarget(e.target)) return

      if (key === 'b') {
        e.preventDefault()
        setDrawMode('paint')
        return
      }
      if (key === 'e') {
        e.preventDefault()
        setDrawMode('line')
        return
      }
      if (key === 'r') {
        e.preventDefault()
        setDrawMode('rect')
        return
      }

      // Backquote is inconsistent across keyboard layouts; accept multiple signals.
      if (
        key === '0' ||
        e.code === 'Backquote' ||
        e.key === '`' ||
        e.key === '~' ||
        e.key === 'Dead'
      ) {
        e.preventDefault()
        setTool(EditorTile.Empty)
        return
      }
      if (key === '1') {
        e.preventDefault()
        setTool(EditorTile.Pellet)
        return
      }
      if (key === '2') {
        e.preventDefault()
        setTool(EditorTile.Wall)
        return
      }
      if (key === '3') {
        e.preventDefault()
        setTool(EditorTile.Exit)
        return
      }
      if (key === '4') {
        e.preventDefault()
        setTool(EditorTile.GhostHouse)
        return
      }
      if (key === '5') {
        e.preventDefault()
        setTool(EditorTile.PowerPellet)
      }
    }

    window.addEventListener('keydown', onKeyDown, { capture: true })
    return () => window.removeEventListener('keydown', onKeyDown, { capture: true })
  }, [])

  const openDuplicatePopup = () => {
    if (!active || !layouts[active]) return
    let base = `${active}_copy`
    if (!validateName(base)) base = 'layout_copy'
    let nextName = base
    let i = 2
    while (layouts[nextName]) {
      nextName = `${base}${i}`
      i++
    }
    setDuplicateNameInput(nextName)
    setShowDuplicatePopup(true)
    setShowRenamePopup(false)
  }

  const duplicateActive = () => {
    const nextName = normalizeName(duplicateNameInput)
    if (!active || !layouts[active]) return
    if (!nextName) {
      setStatus('Enter a layout name.')
      return
    }
    if (!validateName(nextName)) {
      setStatus('Name can use letters, numbers, _ and - only.')
      return
    }
    if (layouts[nextName]) {
      setStatus(`Layout "${nextName}" already exists.`)
      return
    }
    setLayouts((prev) => ({ ...prev, [nextName]: cloneGrid(prev[active]!) }))
    setActive(nextName)
    setRenameNameInput(nextName)
    setShowDuplicatePopup(false)
    setStatus(`Duplicated "${active}" as "${nextName}".`)
  }

  const openRenamePopup = () => {
    if (!active || !layouts[active]) return
    setRenameNameInput(active)
    setShowRenamePopup(true)
    setShowDuplicatePopup(false)
  }

  const renameActive = () => {
    const nextName = normalizeName(renameNameInput)
    if (!active || !layouts[active]) return
    if (!nextName) {
      setStatus('Enter a layout name.')
      return
    }
    if (!validateName(nextName)) {
      setStatus('Name can use letters, numbers, _ and - only.')
      return
    }
    if (nextName === active) {
      setStatus('Layout name is unchanged.')
      return
    }
    if (layouts[nextName]) {
      setStatus(`Layout "${nextName}" already exists.`)
      return
    }
    setLayouts((prev) => {
      const out: EditorGrids = {}
      for (const key of Object.keys(prev)) {
        out[key === active ? nextName : key] = prev[key]!
      }
      return out
    })
    setActive(nextName)
    setShowRenamePopup(false)
    setStatus(`Renamed "${active}" to "${nextName}".`)
  }

  const openDeletePopup = () => {
    if (!active || !layouts[active]) return
    setShowDeletePopup(true)
    setShowDuplicatePopup(false)
    setShowRenamePopup(false)
  }

  const deleteActive = () => {
    if (!active || !layouts[active]) return
    if (layoutNames.length <= 1) {
      setStatus('Cannot delete the last remaining layout.')
      setShowDeletePopup(false)
      return
    }
    const oldName = active
    const remaining = layoutNames.filter((n) => n !== oldName)
    const nextActive = remaining[0] ?? ''
    setLayouts((prev) => {
      const out: EditorGrids = {}
      for (const k of Object.keys(prev)) {
        if (k !== oldName) out[k] = prev[k]!
      }
      return out
    })
    setActive(nextActive)
    setRenameNameInput(nextActive)
    setShowDeletePopup(false)
    setStatus(`Deleted layout "${oldName}".`)
  }

  const save = async () => {
    setStatus('')
    setIsSaving(true)
    try {
      const payload: LevelGridsFile = {}
      for (const name of layoutNames) {
        const g = layouts[name]
        if (!g) continue
        validate14x36(name, g)
        payload[name] = serialize(g)
      }
      const res = await fetch('/__editor/save-level-grids', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(payload),
      })
      if (!res.ok) {
        const text = await res.text().catch(() => '')
        throw new Error(text || `Save failed (${res.status})`)
      }
      setStatus('Saved. Refresh Play to see changes.')
    } catch (e) {
      setStatus(e instanceof Error ? e.message : 'Save failed')
    } finally {
      setIsSaving(false)
    }
  }

  return (
    <section className="editorPage">
      <div className="editorPanel">
        <div className="editorRow">
          <div className="editorTitle">Level Editor</div>
          <button className="btn" onClick={save} disabled={isSaving}>
            {isSaving ? 'Saving…' : 'Save to levelGrids.json'}
          </button>
        </div>

        <div className="editorRow">
          <label className="label">
            Layout
            <select
              className="select"
              value={active}
              onChange={(e) => {
                const name = e.target.value
                setActive(name)
                setRenameNameInput(name)
              }}
            >
              {layoutNames.map((name) => (
                <option key={name} value={name}>
                  {name}
                </option>
              ))}
            </select>
          </label>
        </div>

        <div className="editorRow editorRow--stack">
          <div className="label">Layout actions</div>
          <div className="buttonGroup">
            <button className="btn btn--chip" onClick={openDuplicatePopup} type="button">
              Duplicate current
            </button>
            <button className="btn btn--chip" onClick={openRenamePopup} type="button">
              Rename current
            </button>
            <button className="btn btn--danger" onClick={openDeletePopup} type="button">
              Delete layout
            </button>
          </div>
          {showDuplicatePopup ? (
            <div className="popupPanel">
              <div className="label">Duplicate as</div>
              <div className="renameRow">
                <input
                  className="textInput"
                  type="text"
                  value={duplicateNameInput}
                  onChange={(e) => setDuplicateNameInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key !== 'Enter') return
                    e.preventDefault()
                    duplicateActive()
                  }}
                  placeholder="new-layout-name"
                />
                <button className="btn btn--chip" onClick={duplicateActive} type="button">
                  Create
                </button>
                <button
                  className="btn btn--chip"
                  onClick={() => setShowDuplicatePopup(false)}
                  type="button"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : null}
          {showRenamePopup ? (
            <div className="popupPanel">
              <div className="label">Rename to</div>
              <div className="renameRow">
                <input
                  className="textInput"
                  type="text"
                  value={renameNameInput}
                  onChange={(e) => setRenameNameInput(e.target.value)}
                  onKeyDown={(e) => {
                    if (e.key !== 'Enter') return
                    e.preventDefault()
                    renameActive()
                  }}
                  placeholder="new-layout-name"
                />
                <button className="btn btn--chip" onClick={renameActive} type="button">
                  Rename
                </button>
                <button
                  className="btn btn--chip"
                  onClick={() => setShowRenamePopup(false)}
                  type="button"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : null}
          {showDeletePopup ? (
            <div className="popupPanel popupPanel--danger">
              <div className="label">
                <p>Delete <strong>{active}</strong>? This cannot be undone.</p>
              </div>
              <div className="renameRow">
                <button className="btn btn--danger" onClick={deleteActive} type="button">
                  Confirm delete
                </button>
                <button
                  className="btn btn--chip"
                  onClick={() => setShowDeletePopup(false)}
                  type="button"
                >
                  Cancel
                </button>
              </div>
            </div>
          ) : null}
        </div>

        <div className="editorRow editorRow--stack">
          <div className="label">Tile</div>
          <div className="buttonGroup">
            {(
              [
                [EditorTile.Empty, 'Empty (0)'],
                [EditorTile.Pellet, 'Pellet (1)'],
                [EditorTile.Wall, 'Wall (2)'],
                [EditorTile.Exit, 'Exit (3)'],
                [EditorTile.GhostHouse, 'Ghost house (4)'],
                [EditorTile.PowerPellet, 'Power pellet (5)'],
              ] as const
            ).map(([tile, label]) => (
              <button
                key={tile}
                className={`btn btn--chip${tool === tile ? ' btn--active' : ''}`}
                onClick={() => setTool(tile)}
                type="button"
              >
                {label}
              </button>
            ))}
          </div>
        </div>

        <div className="editorRow editorRow--stack">
          <div className="label">Draw mode</div>
          <div className="buttonGroup">
            {(
              [
                ['paint', 'Paint'],
                ['line', 'Line'],
                ['rect', 'Rectangle'],
              ] as const
            ).map(([mode, label]) => (
              <button
                key={mode}
                className={`btn btn--chip${drawMode === mode ? ' btn--active' : ''}`}
                onClick={() => setDrawMode(mode)}
                type="button"
              >
                {label}
              </button>
            ))}
          </div>
          <div className="hint">
            Paint: click-drag. Line/Rectangle: drag start to end. Right side is mirrored
            preview. Pac and fruit spawns are visual-only.
          </div>
        </div>

        {status ? <div className="status">{status}</div> : null}
      </div>

      <LevelGridEditor
        tiles={tiles}
        onChange={setTiles}
        selected={tool}
        drawMode={drawMode}
        pacSpawn={PAC_SPAWN}
        leftFruitSpawn={LEFT_FRUIT_SPAWN_LOCAL}
      />
    </section>
  )
}

