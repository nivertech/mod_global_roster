-module(mod_global_roster).

-behavior(gen_mod).

-include("ejabberd.hrl").
-export([start/2, stop/1, on_presence_joined/4, on_presence_left/4]).

start(Host, _Opts) ->
  ?INFO_MSG("mod_global_roster starting", []),
  ejabberd_hooks:add(set_presence_hook, Host, ?MODULE, on_presence_joined, 50),
  ejabberd_hooks:add(unset_presence_hook, Host, ?MODULE, on_presence_left, 50),
  ok.

stop(Host) ->
  ?INFO_MSG("mod_global_roster stopping", []),
  ejabberd_hooks:remove(set_presence_hook, Host, ?MODULE, on_presence_joined, 50),
  ejabberd_hooks:remove(unset_presence_hook, Host, ?MODULE, on_presence_left, 50),
  ok.
  
on_presence_joined(User, Server, _Resource, _Packet) ->
  {ok, Client} = client(Server),
  {ok, <<"1">>} = eredis:q(Client, ["SADD", key_name(Server), User]),
  none.

on_presence_left(User, Server, _Resource, _Status) ->
  {ok, Client} = client(Server),
  {ok, <<"1">>} = eredis:q(Client, ["SREM", key_name(Server), User]),
  none.

key_name(Server) ->
  OnlineKey = gen_mod:get_module_opt(Server, ?MODULE, key, "roster:"),
  string:concat(OnlineKey, Server).

redis_host(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_host, "127.0.0.1").

redis_port(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_port, 6379).

redis_db(Server) ->
  gen_mod:get_module_opt(Server, ?MODULE, redis_db, 0).

client(Server) ->
  case whereis(eredis_driver) of
    undefined ->
      case eredis:start_link(redis_host(Server), redis_port(Server), redis_db(Server)) of
        {ok, Client} ->
          register(eredis_driver, Client),
          {ok, Client};
        {error, Reason} ->
          {error, Reason}
      end;
    Pid ->
      {ok, Pid}
  end.
%% TODO
%% Handle redis errors
%% Handle redis returning 0 (if item is in set or cannot be removed)
