const { runPaymentNotifications } = require('../push_scheduler');

async function test() {
  console.log('--- Manual Push Scheduler Run Start ---');
  await runPaymentNotifications();
  console.log('--- Manual Push Scheduler Run End ---');
  process.exit(0);
}

test();
