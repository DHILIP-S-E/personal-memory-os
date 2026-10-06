import { useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { format, isPast } from 'date-fns';
import Badge from '../../components/ui/Badge';
import Button from '../../components/ui/Button';
import Card from '../../components/ui/Card';
import EmptyState from '../../components/ui/EmptyState';
import LoadingSpinner from '../../components/ui/LoadingSpinner';
import CreateReminderModal from './CreateReminderModal';
import { listReminders, updateReminder, deleteReminder } from './remindersApi';
import { parseReminder } from '../ai/aiApi';
import type { Reminder, ParseReminderResponse } from '../../types/index';
import { apiErrorMessage } from '../../lib/apiError';

type FilterTab = 'all' | 'active' | 'completed' | 'overdue';

function isOverdue(r: Reminder): boolean {
  return r.status === 'active' && !!r.scheduled_at && isPast(new Date(r.scheduled_at));
}

export default function RemindersScreen() {
  const queryClient = useQueryClient();
  const [tab, setTab] = useState<FilterTab>('all');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [prefill, setPrefill] = useState<ParseReminderResponse | null>(null);

  // AI parse-reminder state
  const [showAiPanel, setShowAiPanel] = useState(false);
  const [aiText, setAiText] = useState('');
  const [aiParsing, setAiParsing] = useState(false);
  const [aiResult, setAiResult] = useState<ParseReminderResponse | null>(null);
  const [aiError, setAiError] = useState<string | null>(null);

  const { data: allReminders = [], isLoading, error } = useQuery({
    queryKey: ['reminders'],
    queryFn: () => listReminders(),
  });

  const filtered = allReminders.filter(r => {
    if (tab === 'all') return true;
    if (tab === 'active') return r.status === 'active';
    if (tab === 'completed') return r.status === 'completed';
    if (tab === 'overdue') return isOverdue(r);
    return true;
  });

  async function handleMarkComplete(id: string) {
    await updateReminder(id, { status: 'completed' });
    queryClient.invalidateQueries({ queryKey: ['reminders'] });
  }

  async function handleDelete(id: string) {
    if (!confirm('Delete this reminder?')) return;
    await deleteReminder(id);
    queryClient.invalidateQueries({ queryKey: ['reminders'] });
  }

  async function handleAiParse() {
    if (!aiText.trim()) return;
    setAiError(null);
    setAiResult(null);
    setAiParsing(true);
    try {
      const result = await parseReminder(aiText);
      setAiResult(result);
    } catch (err: unknown) {
      setAiError(apiErrorMessage(err, 'AI parsing failed'));
    } finally {
      setAiParsing(false);
    }
  }

  function handleConfirmAiReminder() {
    setPrefill(aiResult);
    setShowAiPanel(false);
    setAiResult(null);
    setAiText('');
    setShowCreateModal(true);
  }

  const tabs: { key: FilterTab; label: string }[] = [
    { key: 'all', label: 'All' },
    { key: 'active', label: 'Active' },
    { key: 'completed', label: 'Completed' },
    { key: 'overdue', label: 'Overdue' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-textPrimary text-2xl font-bold">Reminders</h1>
        <div className="flex gap-3">
          <Button variant="secondary" size="sm" onClick={() => { setShowAiPanel(v => !v); }}>
            ✨ Parse with AI
          </Button>
          <Button
            variant="primary"
            size="sm"
            onClick={() => { setPrefill(null); setShowCreateModal(true); }}
          >
            + New Reminder
          </Button>
        </div>
      </div>

      {/* AI parse panel */}
      {showAiPanel && (
        <Card className="space-y-3">
          <h2 className="text-textPrimary font-medium">Parse reminder text with AI</h2>
          <textarea
            rows={3}
            value={aiText}
            onChange={e => setAiText(e.target.value)}
            className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent resize-none"
            placeholder="Describe your reminder in natural language, e.g. 'Remind me to submit the project report every Friday at 5pm'"
          />
          <div className="flex gap-3">
            <Button variant="primary" size="sm" onClick={handleAiParse} disabled={aiParsing || !aiText.trim()}>
              {aiParsing ? 'Parsing…' : 'Parse'}
            </Button>
            <Button variant="ghost" size="sm" onClick={() => { setShowAiPanel(false); setAiResult(null); setAiError(null); }}>
              Cancel
            </Button>
          </div>
          {aiError && (
            <p className="text-error text-sm">{aiError}</p>
          )}
          {aiResult && (
            <div className="bg-card rounded-lg p-4 space-y-2 border border-border">
              <p className="text-textSecondary text-xs font-medium uppercase tracking-wide">AI Preview — review before saving</p>
              <p className="text-textPrimary font-semibold">{aiResult.title}</p>
              {aiResult.description && <p className="text-textSecondary text-sm">{aiResult.description}</p>}
              <div className="flex flex-wrap gap-2 text-xs">
                {aiResult.reminder_type && <Badge label={aiResult.reminder_type} />}
                {aiResult.priority && <Badge label={aiResult.priority} />}
                {aiResult.scheduled_at && (
                  <span className="text-textMuted">
                    🕐 {format(new Date(aiResult.scheduled_at), 'PPp')}
                  </span>
                )}
              </div>
              <p className="text-textMuted text-xs">Confirm to open the creation form pre-filled with these values.</p>
              <Button variant="primary" size="sm" onClick={handleConfirmAiReminder}>
                Create this reminder
              </Button>
            </div>
          )}
        </Card>
      )}

      {/* Filter tabs */}
      <div className="flex gap-1 border-b border-border">
        {tabs.map(t => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={[
              'px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px',
              tab === t.key
                ? 'border-accent text-accent'
                : 'border-transparent text-textSecondary hover:text-textPrimary',
            ].join(' ')}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Content */}
      {isLoading ? (
        <div className="flex justify-center py-16">
          <LoadingSpinner size="lg" />
        </div>
      ) : error ? (
        <Card className="text-error text-sm">Failed to load reminders.</Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="🔔"
          title="No reminders"
          subtitle={tab === 'overdue' ? 'No overdue reminders.' : 'Create your first reminder to get started.'}
          actionLabel={tab === 'all' ? '+ New Reminder' : undefined}
          onAction={tab === 'all' ? () => { setPrefill(null); setShowCreateModal(true); } : undefined}
        />
      ) : (
        <div className="space-y-3">
          {filtered.map(r => (
            <ReminderRow
              key={r.id}
              reminder={r}
              onComplete={() => handleMarkComplete(r.id)}
              onDelete={() => handleDelete(r.id)}
            />
          ))}
        </div>
      )}

      {showCreateModal && (
        <CreateReminderModal
          prefill={prefill}
          onClose={() => { setShowCreateModal(false); setPrefill(null); }}
        />
      )}
    </div>
  );
}

interface ReminderRowProps {
  reminder: Reminder;
  onComplete: () => void;
  onDelete: () => void;
}

function ReminderRow({ reminder: r, onComplete, onDelete }: ReminderRowProps) {
  const overdue = isOverdue(r);
  return (
    <Card
      variant="card"
      className={[
        'flex items-center gap-4',
        overdue ? 'border border-error/50' : '',
      ].join(' ')}
    >
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-textPrimary font-medium truncate">{r.title}</span>
          <Badge label={r.priority} />
          <Badge label={r.status} />
          {overdue && <Badge label="overdue" />}
        </div>
        {r.description && (
          <p className="text-textMuted text-sm mt-0.5 truncate">{r.description}</p>
        )}
        {r.scheduled_at && (
          <p className="text-textMuted text-xs mt-1">
            🕐 {format(new Date(r.scheduled_at), 'PPp')}
          </p>
        )}
      </div>
      <div className="flex gap-2 shrink-0">
        {r.status === 'active' && (
          <Button variant="secondary" size="sm" onClick={onComplete}>
            ✓ Complete
          </Button>
        )}
        <Button variant="danger" size="sm" onClick={onDelete}>
          Delete
        </Button>
      </div>
    </Card>
  );
}
