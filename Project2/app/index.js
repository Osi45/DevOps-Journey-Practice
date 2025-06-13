const express = require('express');
const app = express();

app.use(express.json());

let quotes = [
  "Stay hungry, stay foolish.",
  "Be yourself; everyone else is already taken.",
  "Simplicity is the ultimate sophistication."
];

app.get('/quotes', (req, res) => {
  try {
    const randomIndex = Math.floor(Math.random() * quotes.length);
    res.json({ quote: quotes[randomIndex] });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve quote' });
  }
});

app.post('/quotes', (req, res) => {
  try {
    const { quote } = req.body;
    
    if (!quote || typeof quote !== 'string' || quote.trim().length === 0) {
      return res.status(400).json({ error: 'Valid quote string is required' });
    }
    
    const trimmedQuote = quote.trim();
    quotes.push(trimmedQuote);
    res.status(201).json({ 
      message: 'Quote added successfully', 
      quote: trimmedQuote,
      totalQuotes: quotes.length 
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to add quote' });
  }
});

app.get('/quotes/all', (req, res) => {
  try {
    res.json({ quotes, total: quotes.length });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve quotes' });
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, (err) => {
  if (err) {
    console.error('Failed to start server:', err);
    process.exit(1);
  }
  console.log(`Quotes API running on port ${PORT}`);
});

