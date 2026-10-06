import type { ReminderCreate } from '../types/index';

/** One action the AI found in a capture: plain text, or { title, due_at } with a "YYYY-MM-DD" date. */
export type ActionItem = string | { title?: string | null; due_at?: string | null };

const MORNING_HOUR = 9;

/** "2026-10-20" -> 9:00 that day in the user's own timezone (never shifted by UTC), else null. */
export function dueMorning(dueAt: string | null | undefined): Date | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(dueAt ?? '');
  if (!m) return null;
  const date = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), MORNING_HOUR, 0, 0);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function actionTitle(action: ActionItem): string {
  const raw = typeof action === 'string' ? action : action.title ?? '';
  return raw.trim();
}

/** The reminder to create for one suggested action, or null when it has no usable title. */
export function reminderFromAction(
  action: ActionItem,
  timezone: string = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
): ReminderCreate | null {
  const title = actionTitle(action);
  if (!title) return null;
  const due = typeof action === 'string' ? null : dueMorning(action.due_at);
  return {
    title: title.slice(0, 500),
    reminder_type: 'time',
    scheduled_at: due ? due.toISOString() : null,
    timezone,
    priority: 'medium',
    alarm_enabled: true,
    notification_enabled: true,
  };
}
