import { createServer } from 'node:http';
import { createApp } from './app.js';
const app = createApp();
const port = Number(process.env.PORT ?? 3000);
createServer(app).listen(port, () => {
    console.log(`LinkUP Presence API listening on ${port}`);
});
