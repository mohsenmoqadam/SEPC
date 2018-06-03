#!/bin/bash

## === get application parameters
AppName=$1
AppVersion=$2
TAB="$(printf '\t')"
AppNameUpper=$(echo "$AppName" | tr '[:lower:]' '[:upper:]')

## === find rebar path
if [ -f ./script/rebar3 ]; then
    REBAR="./script/rebar3"
elif [ ! -z `which rebar3` ]; then
    REBAR=$(which rebar3)
else
    printf "\e[41mPlease install rebar3. It is not found!\e[0m \n"
    exit 1
fi

## === check application name
if [ ${#AppName} -eq 0 ]; then
    printf "\e[41m Please select a name for your application!\e[0m \n"
    exit
fi
ProjectDir="$(pwd)/$AppName"

## === check application version
if [ ${#AppVersion} -eq 0 ]; then
    AppVersion="1.0.0"
else
    AppVersion=$2
fi

## === pring some information about new application
printf "\e[104mApplication name:\e[0m %s\n" $AppName
printf "\e[104mApplication version:\e[0m %s\n" $AppVersion

## === create erlang project
$REBAR new app $AppName
mkdir $ProjectDir/include
mkdir $ProjectDir/proto
mkdir $ProjectDir/priv
mkdir $ProjectDir/test
mkdir $ProjectDir/script
mkdir $ProjectDir/config
cp ./script/gpb $ProjectDir/script
cp ./script/gpb.hrl $ProjectDir/include
cp ./script/rebar3 $ProjectDir/script

## === creating application header file
cat > $ProjectDir/include/$AppName.hrl << EOF
%% -*- mode:erlang -*-

-ifndef(HEADER_${AppNameUpper}).
-define(HEADER_${AppNameUpper}, true).


-ifdef(TEST).
-define(LOG_ERROR(Format, Args), ct:print(default, 50, Format, Args)).
-define(LOG_INFO(Format, Args), ?LOG_ERROR(Format, Args)).
-define(LOG_DEBUG(Format, Args), ?LOG_ERROR(Format, Args)).
-else.
-define(LOG_ERROR(Format, Args), lager:error(Format, Args)).
-define(LOG_INFO(Format, Args), lager:info(Format, Args)).
-define(LOG_DEBUG(Format, Args), lager:debug(Format, Args)).
-endif.

-endif.
EOF

## === upgrading rebar.conf
cat > $ProjectDir/rebar.config << EOF
%%-*- mode: erlang-*-
{erl_opts, [
            debug_info,
            {parse_transform, lager_transform},
            {lager_truncation_size, 1024}
           ]}.

{ct_opts, [
           {sys_config, "config/test.sys.config"}
          ]}.

{deps, [
        {lager, "3.5.0"},
        {recon, "2.3.2"}
       ]}.

{escript_main_app, $AppName}.
{escript_name, "${AppName}_tools"}.
{escript_emu_args, "%%! -escript main ${AppName}_tools\n"}.
{escript_incl_apps, [$AppName, lager, uuid]}.

{profiles, [
            {test, [
                    {erl_opts, [{d, 'PROFILE', test},
                                {d, 'PROFILE_TEST'},
                                {lager_truncation_size, 10240}]},
                    {deps, [{meck, "0.8.4"}]}
                   ]},
            {dev, [
                   {erl_opts, [{d, 'PROFILE', dev},
                               {d, 'PROFILE_DEV'},
                               {lager_truncation_size, 10240}]},
                   {relx, [
                           {release,
                            {$AppName, "$AppName-version"},
                            [ssl,
                             mnesia,
                             recon,
                             lager,
                             $AppName,
                             {wx, load},
                             {observer, load},
                             {runtime_tools, load}
                            ]},
                           {dev_mode, false},
                           {include_erts, true},
                           {vm_args, "config/dev.vm.args"},
                           {sys_config, "config/dev.sys.config"}
                          ]}
                  ]},
            {stage, [
                     {erl_opts, [{d, 'PROFILE', stage},
                                 {d, 'PROFILE_STAGE'},
                                 {lager_truncation_size, 10240}]},
                     {relx, [
                             {release,
                              {$AppName, "$AppName-version"},
                              [ssl,
                               mnesia,
                               recon,
                               lager,
                               $AppName,
                               {wx, load},
                               {observer, load},
                               {runtime_tools, load}
                              ]},
                             {dev_mode, false},
                             {include_erts, true},
                             {vm_args, "config/stage.vm.args"},
                             {sys_config, "config/stage.sys.config"}
                            ]}
                    ]},
            {prod, [
                    {erl_opts, [{d, 'PROFILE', prod},
                                {d, 'PROFILE_PROD'}]},
                    {relx, [
                            {release,
                             {$AppName, "$AppName-version"},
                             [ssl,
                              mnesia,
                              recon,
                              lager,
                              $AppName
                             ]},
                            {overlay,
                             [{copy, "priv", "priv"}]},
                            {dev_mode, false},
                            {include_erts, true},
                            {vm_args, "config/prod.vm.args"},
                            {sys_config, "config/prod.sys.config"}
                           ]}
                   ]}
           ]}.

{relx, [
        {release,
         {$AppName, "$AppName-version"},
         [ssl,
          mnesia,
          recon,
          lager,
          $AppName,
          {wx, load},
          {observer, load},
          {runtime_tools, load}
         ]},
        {overlay,
         [{copy, "priv", "priv"}]},
        {dev_mode, true},
        {include_erts, false},
        {extended_start_script, true},
        {vm_args, "config/vm.args"},
        {sys_config, "config/sys.config"}
       ]}.

EOF

## === creating application profiling files
cat > $ProjectDir/config/test.sys.config << EOF
%% -*- mode:erlang -*-
[{$AppName, [{k1, v1}, {kn, vn}]},
{lager, [
          {error_logger_hwm, 500},
          {colored, true},
          {handlers, [
                      %% {lager_console_backend, debug},
                      {lager_console_backend, [{level, info}, {formatter, lager_default_formatter},
                                               {formatter_config, ["\e[94m", time, "\e[0m ",
                                                                   "\e[42m[", severity,"]\e[0m ",
                                                                   {module, ["\e[32m", module, "\e[0m", {line, [":\e[92m", line, "\e[0m "], ""}], ""}, "",
                                                                   "\e[91m[\e[0m", message ,"\e[91m]\e[0m" , "\r\n"]}]},
                      {lager_file_backend, [{file, "log/error.log"}, {level, error}]},
                      {lager_file_backend, [{file, "log/console.log"}, {level, info}]},
                      {lager_file_backend, [{file, "log/debug.log"}, {level, debug}]}
                     ]}
         ]
 }].
EOF
cat > $ProjectDir/config/dev.sys.config << EOF
%% -*- mode:erlang -*-
[{$AppName, [{k1, v1}, {kn, vn}]},
{lager, [
          {error_logger_hwm, 500},
          {colored, true},
          {handlers, [
                      %% {lager_console_backend, debug},
                      {lager_console_backend, [{level, info}, {formatter, lager_default_formatter},
                                               {formatter_config, ["\e[94m", time, "\e[0m ",
                                                                   "\e[42m[", severity,"]\e[0m ",
                                                                   {module, ["\e[32m", module, "\e[0m", {line, [":\e[92m", line, "\e[0m "], ""}], ""}, "",
                                                                   "\e[91m[\e[0m", message ,"\e[91m]\e[0m" , "\r\n"]}]},
                      {lager_file_backend, [{file, "log/error.log"}, {level, error}]},
                      {lager_file_backend, [{file, "log/console.log"}, {level, info}]},
                      {lager_file_backend, [{file, "log/debug.log"}, {level, debug}]}
                     ]}
         ]
 }].
EOF
cat > $ProjectDir/config/stage.sys.config << EOF
%% -*- mode:erlang -*-
[{$AppName, [{k1, v1}, {kn, vn}]},
{lager, [
          {error_logger_hwm, 500},
          {colored, true},
          {handlers, [
                      %% {lager_console_backend, debug},
                      {lager_console_backend, [{level, info}, {formatter, lager_default_formatter},
                                               {formatter_config, ["\e[94m", time, "\e[0m ",
                                                                   "\e[42m[", severity,"]\e[0m ",
                                                                   {module, ["\e[32m", module, "\e[0m", {line, [":\e[92m", line, "\e[0m "], ""}], ""}, "",
                                                                   "\e[91m[\e[0m", message ,"\e[91m]\e[0m" , "\r\n"]}]},
                      {lager_file_backend, [{file, "log/error.log"}, {level, error}]},
                      {lager_file_backend, [{file, "log/console.log"}, {level, info}]},
                      {lager_file_backend, [{file, "log/debug.log"}, {level, debug}]}
                     ]}
         ]
 }].
EOF
cat > $ProjectDir/config/prod.sys.config << EOF
%% -*- mode:erlang -*-
[{$AppName, [{k1, v1}, {kn, vn}]},
 {lager, [
          {error_logger_hwm, 50},
          {colored, true},
          {handlers, [
                      %% {lager_console_backend, info},
                      {lager_console_backend, [{level, info}, {formatter, lager_default_formatter},
                                               {formatter_config, ["\e[94m", time, "\e[0m ",
                                                                   "\e[41m[", severity,"]\e[0m ",
                                                                   {module, ["\e[31m", module, "\e[0m", {line, [":\e[91m", line, "\e[0m "], ""}], ""}, "",
                                                                   "\e[91m[\e[0m", message ,"\e[91m]\e[0m" , "\r\n"]}]},
                      {lager_file_backend, [{file, "log/error.log"}, {level, error}]},
                      {lager_file_backend, [{file, "log/console.log"}, {level, info}]}
                     ]}
         ]
 }].
EOF

## === creating EVM profiling files
cat > $ProjectDir/config/test.vm.args << EOF
## Name of the node
-name $AppName-test@127.0.0.1
## Cookie for distributed erlang
-setcookie $AppName_cookie
EOF
cat > $ProjectDir/config/dev.vm.args << EOF
## Name of the node
-name $AppName-dev@127.0.0.1
## Cookie for distributed erlang
-setcookie $AppName-cookie
EOF
cat > $ProjectDir/config/stage.vm.args << EOF
## Name of the node
-name $AppName-stage@$AppName-stage-ip
## Cookie for distributed erlang
-setcookie $AppName-cookie
EOF
cat > $ProjectDir/config/prod.vm.args << EOF
## Name of the node
-name $AppName-prod@$AppName-prod-ip
## Cookie for distributed erlang
-setcookie $AppName-cookie
EOF

## === creating version file
cat > $ProjectDir/Version << EOF
$AppVersion
EOF

## === creating sample protobuff files
cat > $ProjectDir/proto/$AppName.sample.type.proto << EOF
package $AppName.sample.type;
// messageCode = 001
message  Type {
}
EOF
cat > $ProjectDir/proto/$AppName.sample.func.proto << EOF
package $AppName.sample.func;
import "$AppName.sample.type.proto";
// messageCode = 101
message Call {
}
EOF

## === creating Makefile
cat > $ProjectDir/Makefile << EOF
PWD   := \$(shell pwd)
SCP   := \$(shell which scp)
CP    := \$(shell which cp)
MV    := \$(shell which mv)
MKDIR := \$(shell which mkdir)
RM    := \$(shell which rm)
SED   := \$(shell which sed)
VER   := \$(shell cat ./Version)
TMP   := /tmp
TAR   := \$(shell which tar)
FS    := username@file.server.address:~/path.in.home

.PHONY: proto compile\
        shell test\
	    console-dev\
		rel-dev rel-stage rel-prod

all: proto compile

proto:
	\$(PWD)/script/gpb -pkgs \
	-I \$(PWD)/proto \
	-o-erl \$(PWD)/src \
	-o-hrl \$(PWD)/include \
	\$(PWD)/proto/*.proto

compile:
	\$(PWD)/script/rebar3 compile

shell:
	\$(PWD)/script/rebar3 shell

test:
	\$(PWD)/script/rebar3 ct

console-dev:
	\$(SED) -i .backup 's/{$AppName, "$AppName-version"}/{$AppName, "\$(VER)"}/g' ./rebar.config
	\$(PWD)/script/rebar3 as dev release
	\$(PWD)/script/rebar3 as dev tar
	\$(RM) \$(PWD)/rebar.config
	\$(MV) \$(PWD)/rebar.config.backup \$(PWD)/rebar.config
	\$(MV) \$(PWD)/_build/dev/rel/$AppName/$AppName-\$(VER).tar.gz \$(TMP)
	\$(RM) -rf \$(TMP)/$AppName
	\$(MKDIR) \$(TMP)/$AppName
	\$(TAR) -zxvf \$(TMP)/$AppName-\$(VER).tar.gz -C \$(TMP)/$AppName
	\$(TMP)/$AppName/bin/$AppName console

rel-prod:
	\$(SED) -i .backup 's/{$AppName, "$AppName-version"}/{$AppName, "\$(VER)"}/g' ./rebar.config
	\$(PWD)/script/rebar3 as prod release
	\$(PWD)/script/rebar3 as prod tar
	\$(RM) \$(PWD)/rebar.config
	\$(MV) \$(PWD)/rebar.config.backup \$(PWD)/rebar.config
	#\$(SCP) -P 8522 \$(PWD)/_build/prod/rel/$AppName/$AppName-\$(VER).tar.gz \$(FS)
${TAB}@printf "\nApplication: %s\n" \$(PWD)/_build/prod/rel/$AppName/$AppName-\$(VER).tar.gz

rel-stage:
	\$(SED) -i .backup 's/{$AppName, "$AppName-version"}/{$AppName, "\$(VER)"}/g' ./rebar.config
	\$(PWD)/script/rebar3 as stage release
	\$(PWD)/script/rebar3 as stage tar
	\$(RM) \$(PWD)/rebar.config
	\$(MV) \$(PWD)/rebar.config.backup \$(PWD)/rebar.config
	#\$(SCP) -P 8522 \$(PWD)/_build/stage/rel/$AppName/$AppName-\$(VER).tar.gz \$(FS)
${TAB}@printf "\nApplication: %s\n" \$(PWD)/_build/stage/rel/$AppName/$AppName-\$(VER).tar.gz

EOF

## === git initalization
git init $ProjectDir
echo "
*~
\#*\#
.\#*" >> $ProjectDir/.gitignore
