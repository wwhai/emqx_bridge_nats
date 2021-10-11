-module(emqx_bridge_nats).

-include_lib("emqx/include/emqx.hrl").
-include_lib("emqx/include/logger.hrl").

-include("emqx_bridge_nats.hrl").

-export([load/1, unload/0]).
% 
-export([on_client_connected/3,
         on_client_disconnected/4,
         on_client_authenticate/3,
         on_client_subscribe/4,
         on_client_unsubscribe/4,
         on_message_publish/2]).

%% Called when the plugin application start
load(Env) ->
    emqx:hook('client.connected', {?MODULE, on_client_connected, [Env]}),
    emqx:hook('client.disconnected', {?MODULE, on_client_disconnected, [Env]}),
    emqx:hook('client.authenticate', {?MODULE, on_client_authenticate, [Env]}),
    emqx:hook('client.subscribe', {?MODULE, on_client_subscribe, [Env]}),
    emqx:hook('client.unsubscribe', {?MODULE, on_client_unsubscribe, [Env]}),
    emqx:hook('message.publish', {?MODULE, on_message_publish, [Env]}).

%% Called when the plugin application stop
unload() ->
    emqx:unhook('client.connected', {?MODULE, on_client_connected}),
    emqx:unhook('client.disconnected', {?MODULE, on_client_disconnected}),
    emqx:unhook('client.authenticate', {?MODULE, on_client_authenticate}),
    emqx:unhook('client.subscribe', {?MODULE, on_client_subscribe}),
    emqx:unhook('client.unsubscribe', {?MODULE, on_client_unsubscribe}),
    emqx:unhook('message.publish', {?MODULE, on_message_publish}).


%%--------------------------------------------------------------------
%% Client Lifecircle Hooks
%%--------------------------------------------------------------------


on_client_connected(ClientInfo = #{clientid := ClientId}, ConnInfo, [_NatsAddress, _NatsPort, Conn]) ->
    io:format("Client(~s) connected, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ClientInfo, ConnInfo]),
    Event = [{action, <<"connected">>}, {clientid, ClientId}],
    Topic = <<"emqx.stream.devices.connected">>,
    produce_nats_pub(Event, Topic, Conn).

on_client_disconnected(ClientInfo = #{clientid := ClientId}, ReasonCode, ConnInfo, [_NatsAddress, _NatsPort, Conn]) ->
    io:format("Client(~s) disconnected due to ~p, ClientInfo:~n~p~n, ConnInfo:~n~p~n", [ClientId, ReasonCode, ClientInfo, ConnInfo]),
    Event = [{action, <<"disconnected">>}, {clientid, ClientId}, {reasonCode, ReasonCode}],
    Topic = <<"emqx.stream.devices.disconnected">>,
    produce_nats_pub(Event, Topic, Conn).

on_client_authenticate(_ClientInfo = #{clientid := ClientId}, Result, _Env) ->
    io:format("Client(~s) authenticate, Result:~n~p~n", [ClientId, Result]),
    {ok, Result}.

on_client_subscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will subscribe: ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

on_client_unsubscribe(#{clientid := ClientId}, _Properties, TopicFilters, _Env) ->
    io:format("Client(~s) will unsubscribe ~p~n", [ClientId, TopicFilters]),
    {ok, TopicFilters}.

%%--------------------------------------------------------------------
%% Message PubSub Hooks
%%--------------------------------------------------------------------

on_message_publish(Message = #message{topic = <<"$SYS/", _/binary>>}, _Env) ->
    {ok, Message};

on_message_publish(Message, [_NatsAddress, _NatsPort, Conn]) ->
    io:format("Publish ~s~n", [emqx_message:format(Message)]),
    {ok, Payload} = format_payload(Message),
    Topic = <<"emqx.stream.devices.message">>,
    produce_nats_pub(Payload, Topic, Conn),
    {ok, Message}.

%%--------------------------------------------------------------------
%% Private functions
%%--------------------------------------------------------------------

produce_nats_pub(Message, Topic, Conn) ->
    Payload = emqx_json:encode(Message),
    
    case nats:pub(Conn, Topic, #{payload => Payload}) of
        ok ->
            ok;
        {error, not_found} ->
            io:format("{error, not_found}, try to restart conn ~n")
    end.

format_payload(Message) ->
    io:format("ClientId: ~p~n", [Message]),
    Payload = [
        {id, Message#message.id},
        {qos, Message#message.qos},
        {clientid, Message#message.from},
        {topic, Message#message.topic},
        {payload, Message#message.payload}
    ],
    {ok, Payload}.
