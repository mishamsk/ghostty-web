const PREFIX = '\x1b]52;';
const MAX_ENCODED_LENGTH = 16 * 1024 * 1024;
export const CLIPBOARD_MESSAGE_PREFIX = '\x00ghostty-web:clipboard:';

function retainedPrefixSuffix(value) {
  for (let length = Math.min(value.length, PREFIX.length - 1); length > 0; length--) {
    const suffix = value.slice(-length);
    if (PREFIX.startsWith(suffix)) {
      return suffix;
    }
  }
  return '';
}

function decodePayload(payload) {
  if (payload === '?' || payload.length > MAX_ENCODED_LENGTH) {
    return null;
  }
  if (payload !== '' && !/^[A-Za-z0-9+/]*={0,2}$/.test(payload)) {
    return null;
  }

  try {
    return Buffer.from(payload, 'base64').toString('utf8');
  } catch {
    return null;
  }
}

export function createOsc52Parser(onClipboard) {
  let pending = '';

  return {
    push(chunk) {
      pending += chunk;

      while (pending.length > 0) {
        const start = pending.indexOf(PREFIX);
        if (start < 0) {
          pending = retainedPrefixSuffix(pending);
          return;
        }

        const contentStart = start + PREFIX.length;
        const bell = pending.indexOf('\x07', contentStart);
        const stringTerminator = pending.indexOf('\x1b\\', contentStart);
        const end =
          bell < 0
            ? stringTerminator
            : stringTerminator < 0
              ? bell
              : Math.min(bell, stringTerminator);

        if (end < 0) {
          pending = pending.slice(start);
          if (pending.length > MAX_ENCODED_LENGTH + PREFIX.length + 32) {
            pending = '';
          }
          return;
        }

        const body = pending.slice(contentStart, end);
        const separator = body.indexOf(';');
        if (separator >= 0) {
          const selection = body.slice(0, separator);
          const text = decodePayload(body.slice(separator + 1));
          if (text !== null) {
            onClipboard({ selection, text });
          }
        }

        const terminatorLength = end === bell ? 1 : 2;
        pending = pending.slice(end + terminatorLength);
      }
    },
  };
}

export function encodeClipboardMessage(text) {
  return CLIPBOARD_MESSAGE_PREFIX + JSON.stringify(text);
}
