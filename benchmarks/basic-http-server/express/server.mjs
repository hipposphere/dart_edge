import express from 'express';

const benchmarkPlaintextBody = 'Hello, World!';
const benchmarkJsonPayload = {message: 'Hello, World!'};
const benchmarkEchoPayload = {
  message: 'Echo payload',
  count: 1,
  enabled: true,
};

const app = express();
app.disable('x-powered-by');

app.get('/plaintext', (_, response) => {
  response
    .set('content-type', 'text/plain; charset=utf-8')
    .send(benchmarkPlaintextBody);
});

app.get('/json', (_, response) => {
  response.json(benchmarkJsonPayload);
});

app.get('/users/:id', (request, response) => {
  response.json({id: request.params.id, name: 'Benchmark User'});
});

app.post('/echo', express.json(), (request, response) => {
  response.json(request.body ?? benchmarkEchoPayload);
});

const port = parsePort(process.argv.slice(2));
app.listen(port, '127.0.0.1');

function parsePort(args) {
  const portArgument = args.find((argument) => argument.startsWith('--port='));
  if (portArgument === undefined) {
    return 8080;
  }

  return Number.parseInt(portArgument.slice('--port='.length), 10);
}
