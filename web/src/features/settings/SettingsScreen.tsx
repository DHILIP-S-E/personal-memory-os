import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import apiClient from '../../lib/apiClient';
import { useAuth } from '../auth/AuthContext';
import Button from '../../components/ui/Button';
import Card from '../../components/ui/Card';
import LoadingSpinner from '../../components/ui/LoadingSpinner';
import { apiErrorMessage } from '../../lib/apiError';

// ──────────────────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────────────────

// ──────────────────────────────────────────────────────────────────────────────
// Delete confirmation dialog
// ──────────────────────────────────────────────────────────────────────────────
interface DeleteDialogProps {
  onCancel: () => void;
  onConfirm: () => Promise<void>;
}

function DeleteDialog({ onCancel, onConfirm }: DeleteDialogProps) {
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const ready = input === 'DELETE';

  async function handleConfirm() {
    if (!ready) return;
    setLoading(true);
    setError(null);
    try {
      await onConfirm();
    } catch (err: unknown) {
      setError(apiErrorMessage(err, 'Failed to delete account'));
      setLoading(false);
    }
  }

  return (
    /* backdrop */
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4">
      <div className="w-full max-w-md bg-surface rounded-2xl p-6 space-y-5 border border-error/50">
        <h2 className="text-textPrimary text-xl font-bold">Delete account</h2>
        <p className="text-textSecondary text-sm">
          This action is <span className="text-error font-semibold">permanent</span> and
          cannot be undone. All your data — reminders, events, captures, and memories —
          will be deleted.
        </p>
        <div>
          <label className="block text-textSecondary text-xs mb-1">
            Type <span className="text-error font-bold">DELETE</span> to confirm
          </label>
          <input
            type="text"
            value={input}
            onChange={e => setInput(e.target.value)}
            className="w-full bg-card border border-border rounded-lg px-3 py-2 text-textPrimary text-sm focus:outline-none focus:ring-1 focus:ring-error"
            placeholder="DELETE"
            autoFocus
          />
        </div>
        {error && <p className="text-error text-sm">{error}</p>}
        <div className="flex gap-3 justify-end">
          <Button variant="secondary" onClick={onCancel} disabled={loading}>
            Cancel
          </Button>
          <Button variant="danger" onClick={handleConfirm} disabled={!ready || loading}>
            {loading ? <LoadingSpinner size="sm" /> : 'Delete my account'}
          </Button>
        </div>
      </div>
    </div>
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Main screen
// ──────────────────────────────────────────────────────────────────────────────
export default function SettingsScreen() {
  const navigate = useNavigate();
  const { user, signOut } = useAuth();
  const email = user?.email ?? null;
  const [exportLoading, setExportLoading] = useState(false);
  const [exportError, setExportError] = useState<string | null>(null);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);

  // ── Export ──────────────────────────────────────────────────────────────────
  async function handleExport() {
    setExportLoading(true);
    setExportError(null);
    try {
      const res = await apiClient.get('/account/export');
      const json = JSON.stringify(res.data, null, 2);
      const blob = new Blob([json], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'personal-memory-export.json';
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch (err: unknown) {
      setExportError(apiErrorMessage(err, 'Export failed'));
    } finally {
      setExportLoading(false);
    }
  }

  // ── Delete account ──────────────────────────────────────────────────────────
  async function handleDeleteConfirm() {
    await apiClient.delete('/account');
    signOut();
    navigate('/signin', { replace: true });
  }

  return (
    <div className="space-y-8 max-w-2xl">
      {/* Header */}
      <div>
        <h1 className="text-textPrimary text-2xl font-bold">Settings</h1>
        <p className="text-textSecondary text-sm mt-1">Manage your account and data.</p>
      </div>

      {/* Account section */}
      <Card className="space-y-3">
        <h2 className="text-textPrimary font-semibold">Account</h2>
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-accent flex items-center justify-center text-white font-bold text-lg">
            {email ? email[0].toUpperCase() : '?'}
          </div>
          <div>
            <p className="text-textPrimary text-sm font-medium">
              {email ?? 'Loading…'}
            </p>
            <p className="text-textMuted text-xs">Signed in with your Personal Memory OS account</p>
          </div>
        </div>
      </Card>

      {/* Data section */}
      <Card className="space-y-3">
        <h2 className="text-textPrimary font-semibold">Data</h2>
        <p className="text-textSecondary text-sm">
          Download a full export of your data as a JSON file.
        </p>
        {exportError && <p className="text-error text-sm">{exportError}</p>}
        <Button
          variant="secondary"
          onClick={() => void handleExport()}
          disabled={exportLoading}
        >
          {exportLoading ? (
            <>
              <LoadingSpinner size="sm" /> Exporting…
            </>
          ) : (
            '⬇ Export All Data'
          )}
        </Button>
      </Card>

      {/* Danger zone */}
      <Card className="space-y-3 border border-error/40">
        <h2 className="text-error font-semibold">Danger Zone</h2>
        <p className="text-textSecondary text-sm">
          Permanently delete your account and all associated data. This cannot be undone.
        </p>
        <Button variant="danger" onClick={() => setShowDeleteDialog(true)}>
          Delete My Account
        </Button>
      </Card>

      {/* Delete confirmation dialog */}
      {showDeleteDialog && (
        <DeleteDialog
          onCancel={() => setShowDeleteDialog(false)}
          onConfirm={handleDeleteConfirm}
        />
      )}
    </div>
  );
}
