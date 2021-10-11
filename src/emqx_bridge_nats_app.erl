-module(emqx_bridge_nats_app).

-behaviour(application).
-include("emqx_bridge_nats.hrl").

-emqx_plugin(?MODULE).

-export([ start/2
        , stop/1
        ]).

start(_StartType, _StartArgs) ->
    {ok, _} = application:ensure_all_started(teacup_nats),
    {ok, Sup} = emqx_bridge_nats_sup:start_link(),
    NatsAddress = application:get_env(?APP, address, "127.0.0.1"),
    NatsPort = application:get_env(?APP, port, 4222),
    case nats:connect(list_to_binary(NatsAddress), NatsPort) of
        {ok, Conn} -> 
            ets:new(?APP, [named_table, protected, set, {keypos, 1}]),
            ets:insert(?APP, {nats_conn, Conn}),
            emqx_bridge_nats:load([]),
            {ok, Sup};
        {error, Reason} -> {error, Reason}
    end.

stop(_State) ->
    emqx_bridge_nats:unload().
