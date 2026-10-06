import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import Button from '../../components/ui/Button';
import { createReminder } from './remindersApi';
import type { ReminderCreate, ParseReminderResponse } from '../../types/index';
import { apiErrorMessage } from '../../lib/apiError';

interface CreateReminderModalProps {
  onClose: () => void;
  prefill?: ParseReminderResponse | null;
}

const defaultForm = (): ReminderCreate => ({
  title: '',
  description: null,
  reminder_type: 'time',
  scheduled_at: null,
  timezone: 'UTC',
  priority: 'medium',
  alarm_enabled: true,
  notification_enabled: true,
  recurrence_rule: null,
  offsets: [],
});

function fromPrefill(p: ParseReminderResponse): ReminderCreate {
  return {
    title: p.title ?? '',
    description: p.description ?? null,
    reminder_type: (p.reminder_type as ReminderCreate['reminder_type']) ?? 'time',
    scheduled_at: p.scheduled_at ?? null,
    timezone: p.timezone ?? 'UTC',
    priority: (p.priority as ReminderCreate['priority']) ?? 'medium',
    alarm_enabled: true,
    notification_enabled: true,
    recurrence_rule: p.recurrence_rule ?? null,
    offsets: p.offsets ?? [],
  };
}

export default function CreateReminderModal({ onClose, prefill }: CreateReminderModalProps) {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<ReminderCreate>(prefill ? fromPrefill(prefill) : defaultForm());
  const [offsetsText, setOffsetsText] = useState((prefill?.offsets ?? []).join(','));
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function set<K extends keyof ReminderCreate>(key: K, value: ReminderCreate[K]) {
    setForm(prev => ({ ...prev, [key]: value }));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      const offsets = offsetsText
        .split(',')
        .map(s => s.trim())
        .filter(Boolean);
      await createReminder({ ...form, offsets });
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      onClose();
    } catch (err: unknown) {
      const msg = apiErrorMessage(err, 'Failed to create reminder');
      setError(msg);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60"
      role="dialog"
      aria-modal="true"
      aria-label="Create Reminder"
    >
      <div className="bg-surface rounded-xl w-full max-w-lg mx-4 max-h-[90vh] overflow-y-auto shadow-2xl">
        <div className="flex items-center justify-between p-6 border-b border-border">
          <h2 className="text-textPrimary text-xl font-semibold">New Reminder</h2>
          <button
            onClick={onClose}
            className="text-textMuted hover:text-textPrimary transition-colors text-2xl leading-none"
            aria-label="Close"
          >
            &times;
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-4">
          {error && (
            <div className="bg-red-900/40 border border-red-700 text-red-300 rounded-lg px-4 py-3 text-sm">
              {error}
            </div>
          )}

          {/* Title */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-title">
              Title <span className="text-error">*</span>
            </label>
            <input
              id="cr-title"
              type="text"
              required
              value={form.title}
              onChange={e => set('title', e.target.value)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              placeholder="Reminder title"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-desc">
              Description
            </label>
            <textarea
              id="cr-desc"
              rows={2}
              value={form.description ?? ''}
              onChange={e => set('description', e.target.value || null)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent resize-none"
              placeholder="Optional description"
            />
          </div>

          {/* Type + Priority */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-type">
                Type
              </label>
              <select
                id="cr-type"
                value={form.reminder_type}
                onChange={e => set('reminder_type', e.target.value as ReminderCreate['reminder_type'])}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              >
                <option value="time">Time</option>
                <option value="deadline">Deadline</option>
                <option value="recurring">Recurring</option>
                <option value="follow-up">Follow-up</option>
                <option value="multi-stage">Multi-stage</option>
              </select>
            </div>
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-priority">
                Priority
              </label>
              <select
                id="cr-priority"
                value={form.priority}
                onChange={e => set('priority', e.target.value as ReminderCreate['priority'])}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              >
                <option value="low">Low</option>
                <option value="medium">Medium</option>
                <option value="high">High</option>
                <option value="critical">Critical</option>
              </select>
            </div>
          </div>

          {/* Scheduled At + Timezone */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-scheduled">
                Scheduled At
              </label>
              <input
                id="cr-scheduled"
                type="datetime-local"
                value={form.scheduled_at ? form.scheduled_at.slice(0, 16) : ''}
                onChange={e => set('scheduled_at', e.target.value ? e.target.value + ':00' : null)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              />
            </div>
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-tz">
                Timezone
              </label>
              <input
                id="cr-tz"
                type="text"
                value={form.timezone ?? 'UTC'}
                onChange={e => set('timezone', e.target.value)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                placeholder="UTC"
              />
            </div>
          </div>

          {/* Toggles */}
          <div className="flex gap-6">
            <label className="flex items-center gap-2 cursor-pointer select-none text-sm text-textSecondary">
              <input
                type="checkbox"
                checked={form.alarm_enabled ?? true}
                onChange={e => set('alarm_enabled', e.target.checked)}
                className="w-4 h-4 accent-accent"
              />
              Alarm
            </label>
            <label className="flex items-center gap-2 cursor-pointer select-none text-sm text-textSecondary">
              <input
                type="checkbox"
                checked={form.notification_enabled ?? true}
                onChange={e => set('notification_enabled', e.target.checked)}
                className="w-4 h-4 accent-accent"
              />
              Notification
            </label>
          </div>

          {/* Recurrence rule */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-rrule">
              Recurrence Rule
            </label>
            <input
              id="cr-rrule"
              type="text"
              value={form.recurrence_rule ?? ''}
              onChange={e => set('recurrence_rule', e.target.value || null)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              placeholder="e.g. RRULE:FREQ=WEEKLY"
            />
          </div>

          {/* Offsets */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="cr-offsets">
              Offsets (comma-separated, e.g. -3d,-1h)
            </label>
            <input
              id="cr-offsets"
              type="text"
              value={offsetsText}
              onChange={e => setOffsetsText(e.target.value)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              placeholder="-3d,-1h"
            />
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" disabled={saving}>
              {saving ? 'Saving…' : 'Create Reminder'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
