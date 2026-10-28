import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

const SOUNDS = '/usr/share/sounds/freedesktop/stereo'
// Полоска видна всегда; на WARN_AT процентах — одно срочное уведомление
const SHOW_FROM = 0
const WARN_AT = 90

const percent = atom({ plugin: 'task-notify', key: 'percent' } as const, null)
const warned = atom({ plugin: 'task-notify', key: 'warned' } as const, false)

// Последний известный процент контекста — уходит подсказкой x-sosna-ctx (полоска в острове Сосны)
let lastPercent: number | null = null

// Уведомление уходит в демон уведомлений — им является сам шелл (Сосна или Caelestia)
function notify($: EngineInterface, title: string, body: string, urgency = 'normal') {
  const hint = lastPercent === null ? [] : ['-h', `string:x-sosna-ctx:${lastPercent}`]
  void $.process
    .run(['notify-send', '-a', 'Claude Code', '-u', urgency, ...hint, title, body])
    .catch(() => {})
}

// ── Остров Сосны: что Claude делает сейчас, токены и чат ──
// Номер этой сессии: Сосна пишет сообщения из острова в ~/.cache/sosna/claude-inbox-<sid>.txt
const sid = Math.random().toString(36).slice(2, 10)
let lastTokens = 0

function island($: EngineInterface, ...args: string[]) {
  void $.process.run(['qs', '-c', 'sosna', 'ipc', 'call', 'claude', ...args]).catch(() => {})
}

function short(v: unknown, n = 60) {
  const t = String(v ?? '').replace(/\s+/g, ' ').trim()
  return t.length > n ? `${t.slice(0, n)}…` : t
}

// Обрезка без склейки строк — для чата
function clip(v: string, n: number) {
  const t = v.trim()
  return t.length > n ? `${t.slice(0, n)}…` : t
}

function fileName(v: unknown) {
  return String(v ?? '').split('/').pop() ?? ''
}

// Коротко, по-человечески: что делает вызов инструмента
function describe(tool: string, a: Record<string, unknown>) {
  switch (tool) {
    case 'Bash':
      return a.description ? short(a.description) : `Выполняет: ${short(a.command, 50)}`
    case 'Read':
      return `Читает ${fileName(a.file_path)}`
    case 'Edit':
    case 'Write':
      return `Правит ${fileName(a.file_path)}`
    case 'NotebookEdit':
      return `Правит ${fileName(a.notebook_path)}`
    case 'Grep':
      return `Ищет «${short(a.pattern, 40)}»`
    case 'Glob':
      return `Ищет файлы ${short(a.pattern, 40)}`
    case 'WebSearch':
      return `Ищет в сети: ${short(a.query, 40)}`
    case 'WebFetch':
      return `Открывает ${short(a.url, 50)}`
    case 'Agent':
      return `Запускает агента: ${short(a.description, 40)}`
    case 'Skill':
      return `Загружает навык ${short(a.skill, 30)}`
    case 'AskUserQuestion':
      return 'Задаёт тебе вопрос'
    case 'ToolSearch':
      return 'Подбирает инструменты'
    default:
      return short(tool.replace(/^mcp__[^_]+(?:_[^_]+)*?__/, ''), 40)
  }
}

function sound($: EngineInterface, name: string) {
  void $.process.run(['pw-play', `${SOUNDS}/${name}.oga`]).catch(() => {})
}

// Обрезаем ответ до одной короткой строки для тела уведомления
function preview(text: string) {
  const line = text.replace(/[*`#>_]/g, '').replace(/\s+/g, ' ').trim()
  return line.length > 140 ? `${line.slice(0, 140)}…` : line || 'Готово'
}

async function refresh($: EngineInterface) {
  const { context } = await $.session.usage()
  const value = context.percent ?? null
  lastPercent = value
  lastTokens = context.tokens ?? lastTokens
  await update($, percent, () => value)

  if (value === null || value < WARN_AT) {
    // После /compact или /clear снова разрешаем предупреждение
    await update($, warned, () => false)
    return
  }
  if (!(await read($, warned))) {
    await update($, warned, () => true)
    notify($, 'Контекст почти кончился', `Занято ${value}% — скоро будет сжатие`, 'critical')
    sound($, 'dialog-warning')
  }
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const result = await next(e)
    await refresh($)

    // Сообщения из острова Сосны: забираем файл и отправляем как обычный запрос
    $.clock.every(1000, () => {
      void $.process
        .run(['sh', '-c', 'f="$HOME/.cache/sosna/claude-inbox-$0.txt"; [ -s "$f" ] && cat "$f" && rm -f "$f"', sid])
        .then(({ stdout }) => {
          const text = stdout.trim()
          if (text) void $.prompt.submit({ text })
        })
        .catch(() => {})
    })
    return result
  })

  // Начало хода: в острове — запрос и «думает»
  on('turn.start', async ($, e, next) => {
    if ((e as { agentId?: string }).agentId === undefined) {
      if (e.text.trim()) island($, 'user', clip(e.text, 2000), sid)
      island($, 'activity', 'Думает…', String(lastTokens), sid)
    }
    return next(e)
  })

  on('session.compact', async ($, e, next) => {
    const result = await next(e)
    await refresh($)
    return result
  })

  on('tool.call', async ($, e, next) => {
    island($, 'activity', describe(e.tool, e as unknown as Record<string, unknown>), String(lastTokens), sid)
    const result = await next(e)
    await refresh($)
    return result
  })

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    await refresh($)

    // Ходы сабагентов и прерванные Esc не озвучиваем
    if (e.agentId !== undefined) {
      return result
    }
    island($, 'reply', clip(e.isAborted ? 'Прервано' : e.answer || 'Готово', 4000), String(lastTokens), sid)
    island($, 'done', sid)
    if (e.isAborted) {
      return result
    }

    const seconds = Math.round(e.durationMs / 1000)
    if (e.reason === 'error' || e.reason === 'refusal') {
      notify($, 'Claude: задача прервалась', preview(e.answer), 'critical')
      sound($, 'dialog-error')
    } else {
      notify($, `Claude закончил (${seconds} с)`, preview(e.answer))
      sound($, 'complete')
    }

    return result
  })

  // Полоска в конце нижней строки подсказок, рядом с «auto mode on (shift+tab to cycle)»
  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const value = await read($, percent)
    if (value === null || value < SHOW_FROM) {
      return next(e)
    }

    const width = 12
    const filled = Math.round((value / 100) * width)
    const bar = '█'.repeat(filled) + '░'.repeat(width - filled)
    const tail = `  ·  контекст ${bar} ${value}%`

    return next({ ...e, props: { ...e.props, tail: (e.props.tail ?? '') + tail } })
  })
}
