const http = require('http');

const options = {
  hostname: 'localhost',
  port: 3002,
  path: '/api/inquiries',
  method: 'GET',
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN_HERE'
  }
};
// Actually I don't have the token.
// I'll just check the DB one more time.
