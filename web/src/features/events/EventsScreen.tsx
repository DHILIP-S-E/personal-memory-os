import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { format } from 'date-fns';
import { useNavigate } from 'react-router-dom';
import Badge from '../../components/ui/Badge';
import Button from '../../components/ui/Button';
import Card from '../../components/ui/Card';
import EmptyState from '../../components/ui/EmptyState';
import LoadingSpinner from '../../components/ui/LoadingSpinner';
import CreateEventModal from './CreateEventModal';
import { listEvents } from './eventsApi';
import { extractEvent } from '../ai/aiApi';
import type { Event, ExtractEventResponse } from '../../types/index';
import { apiErrorMessage } from '../../lib/apiError';

type FilterTab = 'all' | 'draft' | 'upcoming' | 'active' | 'completed';

export default function EventsScreen() {
  const navigate = useNavigate();
  const [tab, setTab] = useState<FilterTab>('all');
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [prefill, setPrefill] = useState<ExtractEventResponse | null>(null);

  // AI extract panel
  const [showAiPanel, setShowAiPanel] = useState(false);
  const [aiText, setAiText] = useState('');
  const [aiExtracting, setAiExtracting] = useState(false);
  const [aiError, setAiError] = useState<string | null>(null);

  const { data: allEvents = [], isLoading, error } = useQuery({
    queryKey: ['events'],
    queryFn: () => listEvents(),
  });

  const filtered = allEvents.filter(e => {
    if (tab === 'all') return true;
    return e.status === tab;
  });

  async function handleAiExtract() {
    if (!aiText.trim()) return;
    setAiError(null);
    setAiExtracting(true);
    try {
      const result = await extractEvent(aiText);
      setPrefill(result);
      setShowAiPanel(false);
      setAiText('');
      setShowCreateModal(true);
    } catch (err: unknown) {
      setAiError(apiErrorMessage(err, 'AI extraction failed'));
    } finally {
      setAiExtracting(false);
    }
  }

  const tabs: { key: FilterTab; label: string }[] = [
    { key: 'all', label: 'All' },
    { key: 'draft', label: 'Draft' },
    { key: 'upcoming', label: 'Upcoming' },
    { key: 'active', label: 'Active' },
    { key: 'completed', label: 'Completed' },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-textPrimary text-2xl font-bold">Events</h1>
        <div className="flex gap-3">
          <Button variant="secondary" size="sm" onClick={() => setShowAiPanel(v => !v)}>
            ✨ Extract from text
          </Button>
          <Button
            variant="primary"
            size="sm"
            onClick={() => { setPrefill(null); setShowCreateModal(true); }}
          >
            + New Event
          </Button>
        </div>
      </div>

      {/* AI extract panel */}
      {showAiPanel && (
        <Card className="space-y-3">
          <h2 className="text-textPrimary font-medium">Extract event details with AI</h2>
          <p className="text-textMuted text-sm">Paste an email, invitation, or description and AI will pre-fill the creation form. You still submit manually.</p>
          <textarea
            rows={4}
            value={aiText}
            onChange={e => setAiText(e.target.value)}
            className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-accent resize-none"
            placeholder="Paste event text here…"
          />
          <div className="flex gap-3">
            <Button variant="primary" size="sm" onClick={handleAiExtract} disabled={aiExtracting || !aiText.trim()}>
              {aiExtracting ? 'Extracting…' : 'Extract'}
            </Button>
            <Button variant="ghost" size="sm" onClick={() => { setShowAiPanel(false); setAiError(null); }}>
              Cancel
            </Button>
          </div>
          {aiError && <p className="text-error text-sm">{aiError}</p>}
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
        <Card className="text-error text-sm">Failed to load events.</Card>
      ) : filtered.length === 0 ? (
        <EmptyState
          icon="📅"
          title="No events"
          subtitle="Create your first event to get started."
          actionLabel={tab === 'all' ? '+ New Event' : undefined}
          onAction={tab === 'all' ? () => { setPrefill(null); setShowCreateModal(true); } : undefined}
        />
      ) : (
        <div className="space-y-3">
          {filtered.map(ev => (
            <EventCard key={ev.id} event={ev} onClick={() => navigate(`/events/${ev.id}`)} />
          ))}
        </div>
      )}

      {showCreateModal && (
        <CreateEventModal
          prefill={prefill}
          onClose={() => { setShowCreateModal(false); setPrefill(null); }}
        />
      )}
    </div>
  );
}

interface EventCardProps {
  event: Event;
  onClick: () => void;
}

function EventCard({ event: ev, onClick }: EventCardProps) {
  return (
    <Card
      variant="card"
      className="cursor-pointer hover:ring-1 hover:ring-accent transition-all"
    >
      <button
        className="w-full text-left"
        onClick={onClick}
        aria-label={`Open event: ${ev.title}`}
      >
        <div className="flex items-start justify-between gap-3">
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="text-textPrimary font-medium">{ev.title}</span>
              <Badge label={ev.event_type} />
              <Badge label={ev.status} />
            </div>
            <div className="flex flex-wrap gap-3 mt-1 text-textMuted text-xs">
              <span>📅 {format(new Date(ev.start_at), 'PPp')}</span>
              {ev.end_at && <span>→ {format(new Date(ev.end_at), 'PPp')}</span>}
              {ev.is_virtual ? (
                <span className="bg-indigo-900/50 text-indigo-300 px-2 py-0.5 rounded-full">Virtual</span>
              ) : ev.location ? (
                <span>📍 {ev.location}</span>
              ) : null}
            </div>
            <div className="flex gap-3 mt-2 text-textMuted text-xs">
              {ev.photo_count > 0 && <span>📷 {ev.photo_count}</span>}
              {ev.voice_note_count > 0 && <span>🎤 {ev.voice_note_count}</span>}
              {ev.document_count > 0 && <span>📄 {ev.document_count}</span>}
            </div>
          </div>
          <span className="text-textMuted text-lg shrink-0">›</span>
        </div>
      </button>
    </Card>
  );
}
