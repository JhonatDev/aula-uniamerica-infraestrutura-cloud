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

const app = express();
app.use(cors());
app.use(express.json());

// GET /todos
app.get('/todos', async (_req, res) => {
  try {
    const data = await ddb.send(new ScanCommand({ TableName: TABLE_NAME }));
    res.json(data.Items || []);
  } catch (err) {
    console.error('Erro ao buscar tarefas:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST /todos
app.post('/todos', async (req, res) => {
  try {
    const item = {
      id: randomUUID(),
      text: req.body.text,
      completed: false,
    };
    await ddb.send(new PutCommand({ TableName: TABLE_NAME, Item: item }));
    res.status(201).json(item);
  } catch (err) {
    console.error('Erro ao criar tarefa:', err);
    res.status(400).json({ error: err.message });
  }
});

// PATCH /todos/:id
app.patch('/todos/:id', async (req, res) => {
  try {
    const { completed } = req.body;
    await ddb.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { id: req.params.id },
        UpdateExpression: 'set completed = :c',
        ExpressionAttributeValues: { ':c': completed !== undefined ? completed : true },
      })
    );
    res.sendStatus(200);
  } catch (err) {
    console.error('Erro ao atualizar tarefa:', err);
    res.status(500).json({ error: err.message });
  }
});

// DELETE /todos/:id
app.delete('/todos/:id', async (req, res) => {
  try {
    await ddb.send(
      new DeleteCommand({
        TableName: TABLE_NAME,
        Key: { id: req.params.id },
      })
    );
    res.sendStatus(204);
  } catch (err) {
    console.error('Erro ao excluir tarefa:', err);
    res.status(500).json({ error: err.message });
  }
});

module.exports = app;

if (require.main === module) {
  const port = process.env.PORT || 5000;
  app.listen(port, () => {
    console.log(`Servidor rodando na porta ${port}`);
  });
}
