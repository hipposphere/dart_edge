import Fastify from 'fastify';

const benchmarkPlaintextBody = 'Hello, World!';
const benchmarkJsonBody = '{"message":"Hello, World!"}';

const fastify = Fastify({
  logger: false,
  disableRequestLogging: true,
});

fastify.get('/plaintext', async (_, reply) => {
  reply.header('content-type', 'text/plain; charset=utf-8');
  return benchmarkPlaintextBody;
});

fastify.get('/json', async (_, reply) => {
  reply.header('content-type', 'application/json; charset=utf-8');
  return benchmarkJsonBody;
});

fastify.get('/users/:id', async (request, reply) => {
  reply.header('content-type', 'application/json; charset=utf-8');
  return `{"id":"${request.params.id}","name":"Benchmark User"}`;
});

fastify.post('/echo', async (request, reply) => {
  reply.header('content-type', 'application/json; charset=utf-8');
  return request.body ?? '{"message":"Echo payload","count":1,"enabled":true}';
});

const port = parsePort(process.argv.slice(2));
await fastify.listen({
  host: '127.0.0.1',
  port,
});

function parsePort(args) {
  const portArgument = args.find((argument) => argument.startsWith('--port='));
  if (portArgument === undefined) {
    return 8080;
  }

  return Number.parseInt(portArgument.slice('--port='.length), 10);
}
