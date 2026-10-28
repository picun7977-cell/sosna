import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

const HINT = {
  component: 'PromptHint',
  props: { isDraft: false, isWorking: false, hint: 'auto mode on (shift+tab to cycle)' },
} as const

// Под плагином: движок рисует строку подсказки с её tail, контекст заполнен на `percent`, команды не запускаются
function world(on: On, percent: number) {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    const props = e.props as { hint: string; tail?: string }
    return h(Text, {}, props.hint + (props.tail ?? ''))
  })
  on('session.usage', () => ({ value: { startedAt: 0, context: { window: 200000, tokens: percent * 2000, percent }, rateLimits: [] } }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: '', stderr: '' } }))
  on('tool.call', () => ({ result: 'ok' }) as never)
}

async function hintAt($: Parameters<Parameters<typeof test>[1]>[0], on: On, percent: number) {
  world(on, percent)
  await $.tool.call({ tool: 'Bash', input: { command: 'true' } } as never)
  return $.ui.mount({ plugin: 'task-notify', surface: 'terminal', ...HINT })
}

test('в строке подсказки после режима идёт полоска с процентом', async ($, on) => {
  const ui = await hintAt($, on, 72)
  expect(await ui.find({ type: 'Text', text: /shift\+tab to cycle.*контекст █+░+ 72%/ })).toBeDefined()
  await ui.unmount()
})

test('полоска есть и при 20%', async ($, on) => {
  const ui = await hintAt($, on, 20)
  expect(await ui.find({ type: 'Text', text: /контекст .* 20%/ })).toBeDefined()
  await ui.unmount()
})
