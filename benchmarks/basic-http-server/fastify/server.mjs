import Fastify from 'fastify';

const benchmarkPlaintextBody = 'Hello, World!';
const benchmarkJsonPayload = {message: 'Hello, World!'};
const benchmarkEchoPayload = {
  message: 'Echo payload',
  count: 1,
  enabled: true,
};

const fastify = Fastify({
  logger: false,
  disableRequestLogging: true,
});

fastify.get('/plaintext', async (_, reply) => {
  reply.header('content-type', 'text/plain; charset=utf-8');
  return benchmarkPlaintextBody;
});

fastify.get('/json', async () => benchmarkJsonPayload);

fastify.get('/users/:id', async (request) => {
  return {id: request.params.id, name: 'Benchmark User'};
});

fastify.post('/echo', async (request) => {
  return request.body ?? benchmarkEchoPayload;
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
