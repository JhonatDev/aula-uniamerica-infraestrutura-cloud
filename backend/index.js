const express = require('express');
const cors = require('cors');
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const {
  DynamoDBDocumentClient,
  ScanCommand,
  PutCommand,
  UpdateCommand,
  DeleteCommand,
} = require('@aws-sdk/lib-dynamodb');
const { randomUUID } = require('crypto');

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.DYNAMODB_TABLE_NAME || 'Todos';

const parseAllowedOrigins = (value) =>
  (value || 'http://localhost:3000')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);

function createApp({ documentClient = ddb, tableName = TABLE_NAME, allowedOrigins } = {}) {
  const app = express();
  const origins = allowedOrigins || parseAllowedOrigins(process.env.CORS_ALLOWED_ORIGINS);

  app.use(
    cors({
      origin(origin, callback) {
        callback(null, !origin || origins.includes(origin));
      },
    })
  );
  app.use(express.json());

  // GET /todos
  app.get('/todos', async (_req, res) => {
    try {
      const data = await documentClient.send(new ScanCommand({ TableName: tableName }));
      res.json(data.Items || []);
    } catch (err) {
      console.error('Erro ao buscar tarefas:', err);
      res.status(500).json({ error: 'Não foi possível buscar as tarefas.' });
    }
  });

  // POST /todos
  app.post('/todos', async (req, res) => {
    const text = req.body?.text;
    if (typeof text !== 'string' || !text.trim()) {
      return res.status(400).json({ error: 'O campo text é obrigatório.' });
    }

    try {
      const item = {
        id: randomUUID(),
        text: text.trim(),
        completed: false,
      };
      await documentClient.send(new PutCommand({ TableName: tableName, Item: item }));
      return res.status(201).json(item);
    } catch (err) {
      console.error('Erro ao criar tarefa:', err);
      return res.status(500).json({ error: 'Não foi possível criar a tarefa.' });
    }
  });

  // PATCH /todos/:id
  app.patch('/todos/:id', async (req, res) => {
    const { completed } = req.body || {};
    if (typeof completed !== 'boolean') {
      return res.status(400).json({ error: 'O campo completed deve ser booleano.' });
    }

    try {
      await documentClient.send(
        new UpdateCommand({
          TableName: tableName,
          Key: { id: req.params.id },
          UpdateExpression: 'set completed = :c',
          ExpressionAttributeValues: { ':c': completed },
        })
      );
      return res.sendStatus(200);
    } catch (err) {
      console.error('Erro ao atualizar tarefa:', err);
      return res.status(500).json({ error: 'Não foi possível atualizar a tarefa.' });
    }
  });

  // DELETE /todos/:id
  app.delete('/todos/:id', async (req, res) => {
    try {
      await documentClient.send(
        new DeleteCommand({
          TableName: tableName,
          Key: { id: req.params.id },
        })
      );
      return res.sendStatus(204);
    } catch (err) {
      console.error('Erro ao excluir tarefa:', err);
      return res.status(500).json({ error: 'Não foi possível excluir a tarefa.' });
    }
  });

  return app;
}

const app = createApp();

module.exports = app;
module.exports.createApp = createApp;
module.exports.parseAllowedOrigins = parseAllowedOrigins;

if (require.main === module) {
  const port = process.env.PORT || 5000;
  app.listen(port, () => {
    console.log(`Servidor rodando na porta ${port}`);
  });
}
