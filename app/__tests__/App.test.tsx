/**
 * @format
 */

import { render, screen } from '@testing-library/react-native';
import App from '../App';

test('renders the app title as an accessible header', () => {
  render(<App />);

  // Queried by accessibility role + name, so the test fails if the title
  // stops being exposed to VoiceOver as a header (SPECS § 0).
  expect(screen.getByRole('header', { name: 'ScaboPDF' })).toBeOnTheScreen();
});
