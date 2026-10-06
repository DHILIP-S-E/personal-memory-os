import axios from 'axios';

const GENERIC = 'Something went wrong. Please try again.';

/** A pydantic message such as "Value error, Title cannot be empty" -> "Title cannot be empty". */
function cleanDetail(msg: string): string {
  return msg.replace(/^Value error,\s*/i, '').trim();
}

/**
 * A sentence a person can act on, for any error a request can throw.
 * Axios's own text ("Request failed with status code 422") hides the reason the
 * backend gave, so the backend's `detail` is used when there is one.
 */
export function apiErrorMessage(err: unknown, fallback: string = GENERIC): string {
  if (axios.isAxiosError(err)) {
    const res = err.response;
    if (!res) return "Can't reach the server. Check your internet connection and try again.";
    const detail = (res.data as { detail?: unknown } | undefined)?.detail;
    if (typeof detail === 'string' && detail.trim()) return cleanDetail(detail);
    if (Array.isArray(detail) && detail.length > 0) {
      const first = detail[0] as { msg?: unknown };
      if (typeof first?.msg === 'string' && first.msg.trim()) return cleanDetail(first.msg);
    }
    if (res.status === 401 || res.status === 403) return 'Your session has expired. Please sign in again.';
    if (res.status >= 500) return 'The server had a problem. Please try again in a moment.';
    return fallback;
  }
  if (err instanceof Error && err.message && err.message.length < 140) return err.message;
  return fallback;
}
