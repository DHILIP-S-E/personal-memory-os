import { useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import Button from '../../components/ui/Button';
import { createEvent } from './eventsApi';
import type { EventCreate, DeadlineIn, ExtractEventResponse } from '../../types/index';
import { apiErrorMessage } from '../../lib/apiError';

interface CreateEventModalProps {
  onClose: () => void;
  prefill?: ExtractEventResponse | null;
}

interface DeadlineRow extends DeadlineIn {
  key: number;
}

function emptyForm(): EventCreate {
  return {
    title: '',
    description: null,
    event_type: 'meeting',
    start_at: '',
    end_at: null,
    timezone: 'UTC',
    location: null,
    is_virtual: false,
    event_url: null,
    organizer: null,
    registration_url: null,
    deadlines: [],
  };
}

function fromPrefill(p: ExtractEventResponse): EventCreate {
  return {
    title: p.title ?? '',
    description: p.description ?? null,
    event_type: (p.event_type as EventCreate['event_type']) ?? 'meeting',
    start_at: p.start_at ?? '',
    end_at: p.end_at ?? null,
    timezone: p.timezone ?? 'UTC',
    location: p.location ?? null,
    is_virtual: p.is_virtual ?? false,
    event_url: p.event_url ?? null,
    organizer: p.organizer ?? null,
    registration_url: p.registration_url ?? null,
    deadlines: p.deadlines ?? [],
  };
}

const EVENT_TYPES: EventCreate['event_type'][] = [
  'hackathon', 'conference', 'workshop', 'webinar', 'meetup',
  'meeting', 'appointment', 'deadline', 'custom',
];

export default function CreateEventModal({ onClose, prefill }: CreateEventModalProps) {
  const queryClient = useQueryClient();
  const [form, setForm] = useState<EventCreate>(prefill ? fromPrefill(prefill) : emptyForm());
  const [deadlines, setDeadlines] = useState<DeadlineRow[]>(
    (prefill?.deadlines ?? []).map((d, i) => ({ ...d, key: i }))
  );
  const [nextKey, setNextKey] = useState(prefill?.deadlines?.length ?? 0);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function set<K extends keyof EventCreate>(key: K, value: EventCreate[K]) {
    setForm(prev => ({ ...prev, [key]: value }));
  }

  function addDeadlineRow() {
    setDeadlines(prev => [...prev, { key: nextKey, title: '', deadline_type: 'submission', deadline_at: '' }]);
    setNextKey(k => k + 1);
  }

  function removeDeadlineRow(key: number) {
    setDeadlines(prev => prev.filter(d => d.key !== key));
  }

  function updateDeadlineRow(key: number, field: keyof DeadlineIn, value: string) {
    setDeadlines(prev => prev.map(d => d.key === key ? { ...d, [field]: value } : d));
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSaving(true);
    try {
      const payload: EventCreate = {
        ...form,
        deadlines: deadlines.map(({ key: _k, ...d }) => d),
      };
      await createEvent(payload);
      queryClient.invalidateQueries({ queryKey: ['events'] });
      onClose();
    } catch (err: unknown) {
      setError(apiErrorMessage(err, 'Failed to create event'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60"
      role="dialog"
      aria-modal="true"
      aria-label="Create Event"
    >
      <div className="bg-surface rounded-xl w-full max-w-2xl mx-4 max-h-[90vh] overflow-y-auto shadow-2xl">
        <div className="flex items-center justify-between p-6 border-b border-border">
          <h2 className="text-textPrimary text-xl font-semibold">New Event</h2>
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
            <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-title">
              Title <span className="text-error">*</span>
            </label>
            <input
              id="ce-title"
              type="text"
              required
              value={form.title}
              onChange={e => set('title', e.target.value)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              placeholder="Event title"
            />
          </div>

          {/* Description */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-desc">
              Description
            </label>
            <textarea
              id="ce-desc"
              rows={2}
              value={form.description ?? ''}
              onChange={e => set('description', e.target.value || null)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent resize-none"
            />
          </div>

          {/* Event type */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-type">
              Event Type
            </label>
            <select
              id="ce-type"
              value={form.event_type}
              onChange={e => set('event_type', e.target.value as EventCreate['event_type'])}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
            >
              {EVENT_TYPES.map(t => (
                <option key={t} value={t}>{t.charAt(0).toUpperCase() + t.slice(1)}</option>
              ))}
            </select>
          </div>

          {/* Start / End */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-start">
                Start At <span className="text-error">*</span>
              </label>
              <input
                id="ce-start"
                type="datetime-local"
                required
                value={form.start_at ? form.start_at.slice(0, 16) : ''}
                onChange={e => set('start_at', e.target.value ? e.target.value + ':00' : '')}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              />
            </div>
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-end">
                End At
              </label>
              <input
                id="ce-end"
                type="datetime-local"
                value={form.end_at ? form.end_at.slice(0, 16) : ''}
                onChange={e => set('end_at', e.target.value ? e.target.value + ':00' : null)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              />
            </div>
          </div>

          {/* Timezone */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-tz">
              Timezone
            </label>
            <input
              id="ce-tz"
              type="text"
              value={form.timezone ?? 'UTC'}
              onChange={e => set('timezone', e.target.value)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
              placeholder="UTC"
            />
          </div>

          {/* Location */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-location">
                Location
              </label>
              <input
                id="ce-location"
                type="text"
                value={form.location ?? ''}
                onChange={e => set('location', e.target.value || null)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                placeholder="City / venue"
              />
            </div>
            <div className="flex items-end pb-2">
              <label className="flex items-center gap-2 cursor-pointer select-none text-sm text-textSecondary">
                <input
                  type="checkbox"
                  checked={form.is_virtual ?? false}
                  onChange={e => set('is_virtual', e.target.checked)}
                  className="w-4 h-4 accent-accent"
                />
                Virtual Event
              </label>
            </div>
          </div>

          {/* URLs */}
          <div className="grid grid-cols-2 gap-4">
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-event-url">
                Event URL
              </label>
              <input
                id="ce-event-url"
                type="url"
                value={form.event_url ?? ''}
                onChange={e => set('event_url', e.target.value || null)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                placeholder="https://..."
              />
            </div>
            <div>
              <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-reg-url">
                Registration URL
              </label>
              <input
                id="ce-reg-url"
                type="url"
                value={form.registration_url ?? ''}
                onChange={e => set('registration_url', e.target.value || null)}
                className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                placeholder="https://..."
              />
            </div>
          </div>

          {/* Organizer */}
          <div>
            <label className="block text-textSecondary text-sm mb-1" htmlFor="ce-organizer">
              Organizer
            </label>
            <input
              id="ce-organizer"
              type="text"
              value={form.organizer ?? ''}
              onChange={e => set('organizer', e.target.value || null)}
              className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
            />
          </div>

          {/* Deadlines */}
          <div>
            <div className="flex items-center justify-between mb-2">
              <label className="text-textSecondary text-sm font-medium">Deadlines</label>
              <Button type="button" variant="ghost" size="sm" onClick={addDeadlineRow}>
                + Add
              </Button>
            </div>
            {deadlines.length === 0 && (
              <p className="text-textMuted text-xs">No deadlines added.</p>
            )}
            {deadlines.map(dl => (
              <div key={dl.key} className="flex gap-2 mb-2 items-start">
                <input
                  type="text"
                  value={dl.title}
                  onChange={e => updateDeadlineRow(dl.key, 'title', e.target.value)}
                  placeholder="Deadline title"
                  className="flex-1 bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                />
                <input
                  type="text"
                  value={dl.deadline_type}
                  onChange={e => updateDeadlineRow(dl.key, 'deadline_type', e.target.value)}
                  placeholder="Type (e.g. submission)"
                  className="w-36 bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                />
                <input
                  type="datetime-local"
                  value={dl.deadline_at ? dl.deadline_at.slice(0, 16) : ''}
                  onChange={e => updateDeadlineRow(dl.key, 'deadline_at', e.target.value ? e.target.value + ':00' : '')}
                  className="w-44 bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent"
                />
                <button
                  type="button"
                  onClick={() => removeDeadlineRow(dl.key)}
                  className="text-textMuted hover:text-error transition-colors px-2 py-2 text-lg leading-none"
                  aria-label="Remove deadline"
                >
                  ×
                </button>
              </div>
            ))}
          </div>

          <div className="flex justify-end gap-3 pt-2">
            <Button type="button" variant="secondary" onClick={onClose}>
              Cancel
            </Button>
            <Button type="submit" variant="primary" disabled={saving}>
              {saving ? 'Saving…' : 'Create Event'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
