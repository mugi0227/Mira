import { createServer } from 'node:http';
import { createApp } from './app.js';

const port = Number(process.env.PORT ?? 8080);
createServer(createApp({ env: process.env })).listen(port, () => {
  console.log(`mira-import-server listening on ${port}`);
});
