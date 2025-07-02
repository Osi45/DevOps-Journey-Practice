const express = require('express');
const app = express();
const PORT = 4000;

app.use(express.json());

let quotes = [
  "Stay hungry, stay foolish.",
  "Be yourself; everyone else is already taken.",
  "Simplicity is the ultimate sophistication."
];

app.get('/', (req, res) => {
  res.send('📚 Welcome to the Quotes API! Try GET /quotes or GET /quotes/all');
});

app.get('/quotes', (req, res) => {
  const randomQuote = quotes[Math.floor(Math.random() * quotes.length)];
  res.send(randomQuote);
});

app.get('/quotes/all', (req, res) => {
  res.json(quotes);
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});
