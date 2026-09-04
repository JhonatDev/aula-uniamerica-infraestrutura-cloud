const { after, before, describe, test } = require('node:test');
const assert = require('node:assert/strict');
const { once } = require('node:events');
const { createApp, parseAllowedOrigins } = require('./index');

describe('API de tarefas', () => {
  const commands = [];
  const documentClient = {
    async send(command) {
      commands.push(command);
      if (command.constructor.name === 'ScanCommand') {
        return { Items: [{ id: '1', text: 'Testar API', completed: false }] };
      }
      return {};
    },
  };

  const app = createApp({
    documentClient,
    tableName: 'TodosTest',
    allowedOrigins: ['https://app.example.com'],
  });
  let server;
  let baseUrl;

  before(async () => {
    server = app.listen(0);
    await once(server, 'listening');
    baseUrl = `http://127.0.0.1:${server.address().port}`;
  });

  after(async () => {
    await new Promise((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });
  });

  test('lista tarefas e aplica CORS somente à origem autorizada', async () => {
    const response = await fetch(`${baseUrl}/todos`, {
      headers: { Origin: 'https://app.example.com' },
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('access-control-allow-origin'), 'https://app.example.com');
    assert.deepEqual(await response.json(), [{ id: '1', text: 'Testar API', completed: false }]);
  });

  test('não libera CORS para origem desconhecida', async () => {
    const response = await fetch(`${baseUrl}/todos`, {
      headers: { Origin: 'https://malicioso.example' },
    });

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('access-control-allow-origin'), null);
  });

  test('rejeita tarefa sem texto', async () => {
    const response = await fetch(`${baseUrl}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: '   ' }),
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'O campo text é obrigatório.' });
  });

  test('normaliza e persiste uma nova tarefa', async () => {
    const response = await fetch(`${baseUrl}/todos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: '  Nova tarefa  ' }),
    });
    const body = await response.json();

    assert.equal(response.status, 201);
    assert.equal(body.text, 'Nova tarefa');
    assert.equal(body.completed, false);
    assert.ok(body.id);

    const putCommand = commands.find((command) => command.constructor.name === 'PutCommand');
    assert.equal(putCommand.input.TableName, 'TodosTest');
    assert.equal(putCommand.input.Item.text, 'Nova tarefa');
  });

  test('rejeita atualização com completed inválido', async () => {
    const response = await fetch(`${baseUrl}/todos/1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed: 'sim' }),
    });

    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'O campo completed deve ser booleano.' });
  });

  test('atualiza o estado de uma tarefa', async () => {
    const response = await fetch(`${baseUrl}/todos/1`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed: true }),
    });

    assert.equal(response.status, 200);
    const updateCommand = commands.findLast(
      (command) => command.constructor.name === 'UpdateCommand'
    );
    assert.deepEqual(updateCommand.input.Key, { id: '1' });
    assert.equal(updateCommand.input.ExpressionAttributeValues[':c'], true);
  });

  test('exclui uma tarefa pelo identificador', async () => {
    const response = await fetch(`${baseUrl}/todos/1`, { method: 'DELETE' });

    assert.equal(response.status, 204);
    const deleteCommand = commands.findLast(
      (command) => command.constructor.name === 'DeleteCommand'
    );
    assert.deepEqual(deleteCommand.input.Key, { id: '1' });
  });
});

test('interpreta a lista de origens permitidas', () => {
  assert.deepEqual(parseAllowedOrigins('https://a.example, https://b.example'), [
    'https://a.example',
    'https://b.example',
  ]);
});
