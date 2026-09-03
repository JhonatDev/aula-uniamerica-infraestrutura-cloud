import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE = process.env.REACT_APP_API_URL || 'http://localhost:5000';
const API_URL = API_BASE.endsWith('/todos') ? API_BASE : `${API_BASE}/todos`;

function App() {
  const [todos, setTodos] = useState([]);
  const [task, setTask] = useState(""); 

  // Função para carregar os todos da API
  const fetchTodos = async () => {
    try {
      const response = await axios.get(API_URL);
      setTodos(response.data || []);
    } catch (err) {
      console.error('Erro ao buscar tarefas:', err);
    }
  };

  // Função para adicionar uma nova tarefa
  const addTodo = async () => {
    if (task.trim()) {
      try {
        const response = await axios.post(API_URL, { text: task });
        setTodos([...todos, response.data]);
        setTask("");
      } catch (err) {
        console.error('Erro ao adicionar tarefa:', err);
      }
    }
  };

  // Função para marcar a tarefa como concluída
  const toggleComplete = async (todo) => {
    const todoId = todo.id || todo._id;
    const newStatus = !todo.completed;
    try {
      await axios.patch(`${API_URL}/${todoId}`, { completed: newStatus });
      setTodos(todos.map(item => (item.id === todoId || item._id === todoId) ? { ...item, completed: newStatus } : item));
    } catch (err) {
      console.error('Erro ao atualizar tarefa:', err);
    }
  };

  // Função para excluir a tarefa
  const deleteTodo = async (id) => {
    try {
      await axios.delete(`${API_URL}/${id}`);
      setTodos(todos.filter(item => (item.id !== id && item._id !== id)));
    } catch (err) {
      console.error('Erro ao excluir tarefa:', err);
    }
  };

  // Carregar a lista de todos ao iniciar o componente
  useEffect(() => {
    fetchTodos();
  }, []);

  return (
    <div className="App">
      <h1>Lista de Tarefas</h1>
      <div>
        <input 
          type="text" 
          value={task} 
          onChange={(e) => setTask(e.target.value)} 
          placeholder="Adicione uma tarefa"
        />
        <button onClick={addTodo}>Adicionar</button>
      </div>
      <ul>
        {todos.map((todo) => {
          const todoId = todo.id || todo._id;
          return (
            <li key={todoId} style={{ textDecoration: todo.completed ? "line-through" : "none" }}>
              <span onClick={() => toggleComplete(todo)}>{todo.text}</span>
              <button onClick={() => deleteTodo(todoId)}>Excluir</button>
            </li>
          );
        })}
      </ul>
    </div>
  );
}

export default App;
