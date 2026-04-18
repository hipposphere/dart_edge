import express from 'express';

const benchmarkPlaintextBody = 'Hello, World!';
const benchmarkJsonBody = '{"message":"Hello, World!"}';
const benchmarkEchoBody = '{"message":"Echo payload","count":1,"enabled":true}';

const app = express();
app.disable('x-powered-by');

app.get('/plaintext', (_, response) => {
  response
    .set('content-type', 'text/plain; charset=utf-8')
    .send(benchmarkPlaintextBody);
});

app.get('/json', (_, response) => {
  response
    .set('content-type', 'application/json; charset=utf-8')
    .send(benchmarkJsonBody);
});

app.get('/users/:id', (request, response) => {
  response
    .set('content-type', 'application/json; charset=utf-8')
    .send(`{"id":"${request.params.id}","name":"Benchmark User"}`);
});

app.post('/echo', express.text({type: '*/*'}), (request, response) => {
  response
    .set('content-type', 'application/json; charset=utf-8')
    .send(request.body || benchmarkEchoBody);
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
