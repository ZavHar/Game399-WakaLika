import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

function formatLevelGridsFile(data: Record<string, unknown>) {
  const fmtGrid = (name: string, grid: unknown) => {
    const rows = grid as unknown[]
    const rendered = rows.map((row) => `    [${(row as unknown[]).join(',')}]`).join(',\n')
    return `  "${name}": [\n${rendered}\n  ]`
  }
  const keys = Object.keys(data)
  const sections = keys.map((k) => fmtGrid(k, data[k]!)).join(',\n')
  return `{\n${sections}\n}\n`
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    {
      name: 'level-editor-save-endpoint',
      configureServer(server) {
        server.middlewares.use('/__editor/save-level-grids', async (req, res, next) => {
          try {
            if (req.method !== 'POST') return next()
            const chunks: Buffer[] = []
            req.on('data', (c) => chunks.push(Buffer.from(c)))
            req.on('error', (e) => {
              throw e
            })
            await new Promise<void>((resolve) => req.on('end', () => resolve()))

            const text = Buffer.concat(chunks).toString('utf-8')
            const body = JSON.parse(text) as Record<string, unknown>

            const validateGrid = (name: string, g: unknown) => {
              if (!Array.isArray(g) || g.length !== 36) {
                throw new Error(`${name} must be an array of 36 rows`)
              }
              for (let y = 0; y < 36; y++) {
                const row = (g as unknown[])[y]
                if (!Array.isArray(row) || row.length !== 14) {
                  throw new Error(`${name} row ${y} must have 14 cols`)
                }
                for (let x = 0; x < 14; x++) {
                  const v = (row as unknown[])[x]
                  if (v !== 0 && v !== 1 && v !== 2 && v !== 3 && v !== 4 && v !== 5) {
                    throw new Error(`${name} has invalid tile at ${x},${y}`)
                  }
                }
              }
            }

            const names = Object.keys(body)
            if (names.length === 0) throw new Error('At least one layout is required')
            for (const name of names) {
              if (!/^[A-Za-z0-9_-]+$/.test(name)) {
                throw new Error(`Invalid layout name "${name}"`)
              }
              validateGrid(name, body[name])
            }

            const out = formatLevelGridsFile(body)
            const __dirname = path.dirname(fileURLToPath(import.meta.url))
            const outPath = path.join(__dirname, 'src', 'game', 'data', 'levelGrids.json')
            await fs.writeFile(outPath, out, 'utf-8')

            res.statusCode = 200
            res.setHeader('content-type', 'text/plain')
            res.end('ok')
          } catch (e) {
            res.statusCode = 400
            res.setHeader('content-type', 'text/plain')
            res.end(e instanceof Error ? e.message : 'bad request')
          }
        })
      },
    },
  ],
})
