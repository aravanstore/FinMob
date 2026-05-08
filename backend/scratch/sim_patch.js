const fetch = require('node-fetch');

async function test() {
  const loginRes = await fetch('http://localhost:3001/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      username: 'admin',
      password: 'admin', // trying admin first
      union_id: 'd3386ff2-8722-4cf1-b062-8c33974d3b76' // boy
    })
  });
  
  const loginData = await loginRes.json();
  if (!loginData.token) {
    console.error('Login failed:', loginData);
    // try 123456
    const loginRes2 = await fetch('http://localhost:3001/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: 'admin',
        password: '123456',
        union_id: 'd3386ff2-8722-4cf1-b062-8c33974d3b76'
      })
    });
    const loginData2 = await loginRes2.json();
    if (!loginData2.token) {
       console.error('Login 123456 failed too');
       return;
    }
    loginData.token = loginData2.token;
  }
  
  console.log('Logged in! Token:', loginData.token.substring(0, 20) + '...');
  
  const patchRes = await fetch('http://localhost:3001/api/clients/70ad5bd2-64b7-49c7-ab39-51c113266a23', {
    method: 'PATCH',
    headers: { 
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${loginData.token}`
    },
    body: JSON.stringify({
      full_name: 'Абдуллаева Диерахон Ботировна'
    })
  });
  
  const patchData = await patchRes.json();
  console.log('PATCH Response:', patchData);
}

test();
