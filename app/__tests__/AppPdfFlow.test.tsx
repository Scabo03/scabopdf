/**
 * Flow tests for the PDF reading path: a picked PDF is extracted natively,
 * mapped to a Document by the Generic plugin and shown in the reader; and every
 * failure surfaces as an accessible alert rather than being swallowed (the
 * TestFlight UX bug this session fixes).
 *
 * The picker and the native extractor are mocked; the Generic plugin, layout,
 * pagination and rendering run for real.
 */

import { render, fireEvent, waitFor } from '@testing-library/react-native';
import App from '../App';
import { openDocumentFromPicker } from '../src/picker';
import { extractPdf } from '../src/native';
import type { PdfExtraction } from '../src/native';

jest.mock('../src/picker', () => ({
  openDocumentFromPicker: jest.fn(),
}));

// Override only the native extractor; everything else in the native barrel
// (ReadingView, totalLines) stays real.
jest.mock('../src/native', () => {
  const actual = jest.requireActual('../src/native');
  return { ...actual, extractPdf: jest.fn() };
});

const mockedPick = openDocumentFromPicker as jest.MockedFunction<
  typeof openDocumentFromPicker
>;
const mockedExtract = extractPdf as jest.MockedFunction<typeof extractPdf>;

function pickPdf() {
  mockedPick.mockResolvedValue({
    name: 'Manuale.pdf',
    uri: 'file:///tmp/Manuale.pdf',
    kind: 'pdf',
    content: null,
  });
}

const sampleExtraction: PdfExtraction = {
  pageCount: 1,
  pages: [
    {
      pageIndex: 0,
      lines: [
        { text: 'Capitolo Primo', fontSize: 20, bold: true },
        {
          text: 'Il corpo del capitolo che scorre regolarmente.',
          fontSize: 12,
          bold: false,
        },
      ],
    },
  ],
};

describe('App PDF flow', () => {
  beforeEach(() => {
    mockedPick.mockReset();
    mockedExtract.mockReset();
  });

  test('opens a PDF and shows it in the reader', async () => {
    pickPdf();
    mockedExtract.mockResolvedValue(sampleExtraction);

    const { getByLabelText, getByText } = render(<App />);
    fireEvent.press(getByLabelText('Apri documento'));

    await waitFor(() => {
      expect(getByLabelText(/Lettura del documento/)).toBeTruthy();
    });
    expect(getByText('Manuale.pdf')).toBeTruthy();
  });

  test('surfaces a native extraction error as an accessible alert', async () => {
    pickPdf();
    mockedExtract.mockRejectedValue(
      new Error('Il PDF è protetto da password e non può essere letto.'),
    );

    const { getByLabelText, findByRole } = render(<App />);
    fireEvent.press(getByLabelText('Apri documento'));

    const alert = await findByRole('alert');
    expect(alert.props.children).toBe(
      'Il PDF è protetto da password e non può essere letto.',
    );
  });

  test('reports an empty (image-only) PDF accessibly', async () => {
    pickPdf();
    mockedExtract.mockResolvedValue({ pageCount: 3, pages: [] });

    const { getByLabelText, findByRole } = render(<App />);
    fireEvent.press(getByLabelText('Apri documento'));

    const alert = await findByRole('alert');
    expect(alert.props.children).toMatch(/Nessun testo estraibile/);
  });
});
