lua-rpc
=======

lua rpc project for `http://www.inf.puc-rio.br/~noemi/sd-14/trab1.html`

Running unit tests:

    $ busted test.lua

Running integration tests:

    $ lua test_server.lua
    $ lua test_client.lua 127.0.0.1 port1 port2

Running benchmarks:

    $ lua benchmark_server.lua
    $ lua benchmark_client.lua
