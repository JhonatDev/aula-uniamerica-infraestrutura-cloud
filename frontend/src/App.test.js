import { render, screen, waitFor } from '@testing-library/react';
import App from './App';

jest.mock('axios', () => ({
  get: jest.fn(),
  post: jest.fn(),
  patch: jest.fn(),
  delete: jest.fn(),
}));

const axios = require('axios');

test('renderiza a lista e carrega as tarefas da API configurada', async () => {
  axios.get.mockResolvedValueOnce({ data: [] });

  render(<App />);

  expect(screen.getByRole('heading', { name: /lista de tarefas/i })).toBeInTheDocument();
  await waitFor(() => {
    expect(axios.get).toHaveBeenCalledWith('http://localhost:5000/todos');
  });
});
