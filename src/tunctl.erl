%% Copyright (c) 2011, Michael Santos <michael.santos@gmail.com>
%% All rights reserved.
%%
%% Redistribution and use in source and binary forms, with or without
%% modification, are permitted provided that the following conditions
%% are met:
%%
%% Redistributions of source code must retain the above copyright
%% notice, this list of conditions and the following disclaimer.
%%
%% Redistributions in binary form must reproduce the above copyright
%% notice, this list of conditions and the following disclaimer in the
%% documentation and/or other materials provided with the distribution.
%%
%% Neither the name of the author nor the names of its contributors
%% may be used to endorse or promote products derived from this software
%% without specific prior written permission.
%%
%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
%% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
%% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
%% FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
%% COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
%% INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
%% BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
%% LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
%% CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
%% LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
%% ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%% POSSIBILITY OF SUCH DAMAGE.
-module(tunctl).

-include("tuntap.hrl").
-include("ioctl.hrl").
-include("procket.hrl").

-export([
        create/0, create/1, create/2,
        persist/2,
        owner/2, group/2,
        up/2, down/1,

        header/1
    ]).
-export([
        ioctl/3
    ]).


%%--------------------------------------------------------------------
%%% Exports
%%--------------------------------------------------------------------
create() ->
    create(<<>>).
create(Ifname) ->
    create(Ifname, [tap, no_pi]).

create(Ifname, Opt) when byte_size(Ifname) < ?IFNAMSIZ, is_list(Opt) ->
    Module = os(),
    Module:create(Ifname, Opt).


persist(FD, Status) ->
    Module = os(),
    Module:persist(FD, bool(Status)).


%%
%% Change the owner/group of the tun device
%%
owner(FD, Owner) when is_integer(FD), is_integer(Owner) ->
    Module = os(),
    Module:owner(FD, Owner).

group(FD, Group) when is_integer(FD), is_integer(Group) ->
    Module = os(),
    Module:owner(FD, Group).


%%
%% Configure the interface just like ifconfig except
%% with fewer features and no error checking
%%
up(Dev, {A,B,C,D}) ->
    up(Dev, {A,B,C,D}, 24);
up(Dev, {A,B,C,D,E,F,G,H}) ->
    up(Dev, {A,B,C,D,E,F,G,H}, 64).

up(Dev, {A,B,C,D}, Mask) when byte_size(Dev) < ?IFNAMSIZ, is_integer(Mask) ->
    Module = os(),
    case Module of
        tunctl_linux -> tunctl_linux:up(Dev, {A,B,C,D}, Mask);
        _ -> os_up(Dev, {A,B,C,D}, Mask)
    end;
up(Dev, {A,B,C,D,E,F,G,H}, Mask) when byte_size(Dev) < ?IFNAMSIZ, is_integer(Mask) ->
    os_up(Dev, {A,B,C,D,E,F,G,H}, Mask).

down(Dev) when byte_size(Dev) < ?IFNAMSIZ ->
    Module = os(),
    case Module of
        tunctl_linux -> tunctl_linux:down(Dev);
        _ -> os_down(Dev)
    end.


header(<<Flags:?UINT16, Proto:?UINT16, Buf/binary>>) ->
    {tun_pi, Flags, Proto, Buf}.


%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
ioctl(FD, Request, Opt) ->
    case procket:ioctl(FD, Request, Opt) of
        {ok, _} -> ok;
        Error -> Error
    end.

bool(true) -> 1;
bool(false) -> 0.

os() ->
    case os:type() of
        {unix, linux} -> tunctl_linux;
        {unix, darwin} -> tunctl_darwin;
        {unix, freebsd} -> tunctl_freebsd;
        {unix, _} -> throw({error, unsupported})
    end.


%% Shell out to ifconfig on systems where ioctl requires
%% root privs (or native code hasn't been written yet).
os_up(Dev, {A,B,C,D}, Mask) ->
    Cmd = "sudo ifconfig " ++ binary_to_list(Dev) ++ " " ++
    inet_parse:ntoa({A,B,C,D}) ++
    "/" ++ list_to_integer(Mask) ++ " up",
    case os:cmd(Cmd) of
        [] -> ok;
        Error -> {error, Error}
    end;
os_up(Dev, {A,B,C,D,E,F,G,H}, Mask) ->
    Cmd = "sudo ifconfig " ++ binary_to_list(Dev) ++ " inet6 add" ++
    inet_parse:ntoa({A,B,C,D,E,F,G,H}) ++
    "/" ++ list_to_integer(Mask) ++ " up",
    case os:cmd(Cmd) of
        [] -> ok;
        Error -> {error, Error}
    end.

os_down(Dev) ->
    Cmd = "sudo ifconfig " ++ binary_to_list(Dev) ++ " down",
    case os:cmd(Cmd) of
        [] -> ok;
        Error -> {error, Error}
    end.
