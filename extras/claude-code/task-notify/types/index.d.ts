export type ContextPercent = number | null

declare module 'claude-code' {
  interface PluginState {
    'task-notify': { percent: ContextPercent; warned: boolean }
  }
}
