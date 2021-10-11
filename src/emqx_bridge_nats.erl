-module(emqx_bridge_nats).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-include("emqx_bridge_nats.hrl").

-export([load/1, unload/0]).
% 
-export([on_client_connected/3,
         on_client_disconnected/4,
         on_client_authenticate/3,
         on_message_publish/2]).

%% Called when the plugin application start
load(Env) ->
    emqx:hook('client.connected', {?MODULE, on_client_connected, [Env]}),
    emqx:hook('client.disconnected', {?MODULE, on_client_disconnected, [Env]}),
    emqx:hook('client.authenticate', {?MODULE, on_client_authenticate, [Env]}),
    emqx:hook('message.publish', {?MODULE, on_message_publish, [Env]}).

%% Called when the plugin application stop
unload() ->
    emqx:unhook('client.connected', {?MODULE, on_client_connected}),
    emqx:unhook('client.disconnected', {?MODULE, on_client_disconnected}),
    emqx:unhook('client.authenticate', {?MODULE, on_client_authenticate}),
    emqx:unhook('message.publish', {?MODULE, on_message_publish}).


%%--------------------------------------------------------------------
%% Client Lifecircle Hooks
%%--------------------------------------------------------------------


on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, _Env) ->
    io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ClientInfo, ConnInfo]),
    Event = [{action, <<"connected">>}, {clientid, ClientId}],
    Topic = <<"emqx.stream.devices.connected">>,
    publish_to_nats(Event, Topic).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, _Env) ->
    io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ReasonCode, ClientInfo, ConnInfo]),
    Event = [{action, <<"disconnected">>}, {clientid, ClientId}, {reasonCode, ReasonCode}],
    Topic = <<"emqx.stream.devices.disconnected">>,
    publish_to_nats(Event, Topic).

on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result, _Env) ->
    io:format("Client(~s) authenticate, Result:~n~p~n", [ClientId, Result]),
    {ok, Result}.

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, _Env) ->
    io:format("Publish ~s~n", [emqx_message:format(Message)]),
    {ok, Payload} = format_payload(Message),
    Topic = <<"emqx.stream.devices.message">>,
    publish_to_nats(Payload, Topic),
    {ok, Message}.

%%--------------------------------------------------------------------
%% Private functions
%%--------------------------------------------------------------------

publish_to_nats(Message, Topic) ->
    Payload = emqx_json:encode(Message),
    [{_, Conn}] = ets:lookup(?APP, nats_conn),
    case nats:pub(Conn, Topic, #{payload => Payload}) of
        ok ->
            ok;
        {error, not_found} ->
            %% TODO will start a process to reconnect
            io:format("{error, not_found}, try to restart conn ~n")
    end.

format_payload(Message) ->
    io:format("format_payload Message: ~p~n", [Message]),
    Payload = [
        {id, Message#message.id},
        {qos, Message#message.qos},
        {clientid, Message#message.from},
        {topic, Message#message.topic},
        {payload, Message#message.payload}
    ],
    {ok, Payload}.
