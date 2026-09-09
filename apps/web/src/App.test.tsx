import { describe, expect, it } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { App } from './App';

describe('Tipkhun web shell', () => {
  it('renders honest empty dashboard data', () => { render(<MemoryRouter initialEntries={['/dashboard']}><App/></MemoryRouter>); expect(screen.getAllByText(/Tipkhun/).length).toBeGreaterThan(0); expect(screen.getAllByText('ยังไม่มีข้อมูลการเทรด').length).toBeGreaterThan(0); expect(screen.getByText('Simulation / Planning')).toBeTruthy(); });
  it('renders the paper dashboard without claiming live execution', () => { render(<MemoryRouter initialEntries={['/bot']}><App/></MemoryRouter>); expect(screen.getByText('Live: LOCKED')).toBeTruthy(); expect(screen.getByText('Mock Broker only')).toBeTruthy(); });
});
