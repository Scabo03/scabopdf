/**
 * App integration flow (Q3 navigation + the open→parse→render pipeline the
 * audit flagged as untested). Drives the mocked picker through open, the
 * reader with its top-left Close control, return to the documents list, and
 * the error/cancel branches. VoiceOver focus-return after close is best-effort
 * and device-verified; here we assert the functional precondition (the closed
 * document's row is present in the list) and the spoken announcements.
 */

import {
  render,
  screen,
  fireEvent,
  waitFor,
} from '@testing-library/react-native';
import { AccessibilityInfo } from 'react-native';
import { pick } from '@react-native-documents/picker';
import App from '../App';

const VALID_DOC = JSON.stringify({
  schema_version: '0.7.0',
  document_id: '123e4567-e89b-12d3-a456-426614174000',
  metadata: {
    pages_pdf: 1,
    page_size_pt: [595, 842],
    source_pdf_filename: 'x.pdf',
  },
  profile: {
    profile_id: 'unknown_generic',
    editorial_family: 'unknown',
    genre: 'unknown',
    confidence: 0,
  },
  structure: [
    { id: 'node_0', type: 'BODY', page_index: 0, text: 'Testo del documento.' },
  ],
});

function mockPick(name: string, content: string): void {
  (pick as jest.Mock).mockResolvedValueOnce([
    { uri: `file:///tmp/${name}`, name },
  ]);
  jest.spyOn(global, 'fetch').mockResolvedValueOnce({
    text: () => Promise.resolve(content),
  } as unknown as Response);
}

describe('App open/close/reopen flow', () => {
  beforeEach(() => {
    (pick as jest.Mock).mockReset();
    jest.restoreAllMocks();
  });

  test('opens a document into the reader with a top-left Close control', async () => {
    mockPick('legge.scabopdf.json', VALID_DOC);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() =>
      expect(screen.getByLabelText('Chiudi documento')).toBeOnTheScreen(),
    );
    expect(screen.getByText('legge.scabopdf.json')).toBeOnTheScreen();
  });

  test('closing returns to the list with the just-closed document as a row', async () => {
    mockPick('atto.scabopdf.json', VALID_DOC);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() => screen.getByLabelText('Chiudi documento'));

    fireEvent.press(screen.getByLabelText('Chiudi documento'));
    await waitFor(() =>
      expect(screen.getByText('Documenti aperti')).toBeOnTheScreen(),
    );
    // The row is a button labelled by the document name — the reopen target
    // and the VoiceOver focus-return target.
    expect(screen.getByLabelText('atto.scabopdf.json')).toBeOnTheScreen();
    expect(screen.queryByLabelText('Chiudi documento')).toBeNull();
  });

  test('reopens a document from the list', async () => {
    mockPick('rip.scabopdf.json', VALID_DOC);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() => screen.getByLabelText('Chiudi documento'));
    fireEvent.press(screen.getByLabelText('Chiudi documento'));
    await waitFor(() => screen.getByText('Documenti aperti'));

    fireEvent.press(screen.getByLabelText('rip.scabopdf.json'));
    await waitFor(() =>
      expect(screen.getByLabelText('Chiudi documento')).toBeOnTheScreen(),
    );
  });

  test('announces the busy state and the opened document', async () => {
    const announce = jest.spyOn(AccessibilityInfo, 'announceForAccessibility');
    mockPick('x.scabopdf.json', VALID_DOC);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() => screen.getByLabelText('Chiudi documento'));
    expect(announce).toHaveBeenCalledWith('Apertura del documento in corso');
    expect(announce).toHaveBeenCalledWith('Documento x.scabopdf.json aperto');
  });

  test('shows an accessible alert and stays home when the file is invalid', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([
      { uri: 'file:///tmp/bad.json', name: 'bad.json' },
    ]);
    jest.spyOn(global, 'fetch').mockResolvedValueOnce({
      text: () => Promise.resolve('{ not json'),
    } as unknown as Response);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() => expect(screen.getByRole('alert')).toBeOnTheScreen());
    expect(screen.getByLabelText('Apri documento')).toBeOnTheScreen();
    expect(screen.queryByLabelText('Chiudi documento')).toBeNull();
  });

  test('cancelling the picker leaves the home screen unchanged', async () => {
    (pick as jest.Mock).mockResolvedValueOnce([]);
    render(<App />);
    fireEvent.press(screen.getByLabelText('Apri documento'));
    await waitFor(() =>
      expect(screen.getByLabelText('Apri documento')).toBeOnTheScreen(),
    );
    expect(screen.queryByLabelText('Chiudi documento')).toBeNull();
  });
});
