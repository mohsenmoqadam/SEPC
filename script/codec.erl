#!/Users/mohsen/Erlang_21/bin/escript
%% MyMAC:  /Users/mohsen/Erlang_21/bin/escript
%% MyMint: /usr/bin/escript

main([AppName, ProtoDir, Target]) ->
    {ok, ProtoFileNames} = file:list_dir(ProtoDir),
    Pred = fun(ProtoFileName, ACC) ->
                   ProtoFile = ProtoDir ++ "/" ++ ProtoFileName,
                   {_Counts, Lines} = read_lines_of_file(ProtoFile),
                   ACC ++ [get_params(Lines, ProtoFileName)]
           end,
    Params = lists:foldl(Pred, [], ProtoFileNames),
    Module = make_module(AppName ++ "_codec"),
    Definitions = make_difinitions(),
    Types = make_types(),
    Encoders = make_encoders(Params),
    Decoders = make_decoders(Params),
    FileContent = Module ++ Definitions ++ Types ++ Encoders ++ Decoders,
    Bin = list_to_binary(FileContent),
    file:write_file(Target ++ "/" ++ AppName ++ "_codec.erl", Bin),
    halt(0).

-spec read_lines_of_file(string()) -> list().
read_lines_of_file(File) ->
    {ok, Data} = file:read_file(File),
    BinaryLines = binary:split(Data, [<<"\n">>], [global]),
    lists:foldl(fun(<<>>, {I, ACC}) -> {I + 1, ACC};
                   (BL,   {I, ACC}) -> {I + 1, ACC ++ [{I, binary_to_list(BL)}]}
                end,
                {1, []},
                BinaryLines).

-spec get_params(string(), string()) -> string().
get_params(Lines, FileName) ->
    pars_proto_params(Lines, [{file_name, get_file_name(FileName)}]).

-spec pars_proto_params(list(), list()) -> list().
pars_proto_params([], Stack) ->
    Stack;
pars_proto_params([{_LineNumber, Line} | Rest], Stack) ->
    case {get_category(Line), get_package(Line), get_code(Line), get_name(Line)} of
        {skip, skip, skip, skip} ->
            pars_proto_params(Rest, Stack);
        {skip, skip, Code, skip} ->
            pars_proto_params(Rest, Stack ++ [{Code, undefined}]);
        {skip, skip, skip, Name} ->
            {StackRest, [{Code, undefined}]} = lists:split(length(Stack) - 1, Stack),
            pars_proto_params(Rest, StackRest ++ [{Code, Name}]);
        {skip, Package, skip, skip} ->
            pars_proto_params(Rest, Stack ++ [{package, Package}]);
        {Category, skip, skip, skip} ->
            pars_proto_params(Rest, Stack ++ [{category, Category}])
    end.

-spec get_file_name(string()) -> string().
get_file_name(FileName0) ->
    FileName1 = re:replace(FileName0, "../([a-zA-Z0-9_.-/])+/|./([a-zA-Z0-9_.-/])+/|\\s*|.proto|", "", [{return, list}, global]),
    re:replace(FileName1, "\\.", "_", [{return, list}, global]).

-spec get_category(string()) -> string() | skip.
get_category(Line) ->
    case is_category_line(Line) of
        true ->
            %% Get CategoryName From: '// +> categoryName'
            Category = re:replace(Line, "//|\\s*|\\+>|category|=", "", [{return, list}, global]),
            string:uppercase(Category);
        false ->
            skip
    end.

-spec get_package(string()) -> string() | skip.
get_package(Line) ->
    case is_package_line(Line) of
        true ->
            %% Get PackageName From: 'package PackageName;'
            PackageName = re:replace(Line, "package\\s*|;|\\s*", "", [{return, list}, global]),
            PackageName;
        false ->
            skip
    end.

-spec get_code(string()) -> non_neg_integer() | skip.
get_code(Line) ->
    case is_code_line(Line) of
        true ->
            %% Get Code From: '// *> code = 1234'
            re:replace(Line, "//\\s*\\*>\\s*([a-zA-Z])+\\s*=\\s*", "", [{return, list}, global]);
        false ->
            skip
    end.

-spec get_name(string()) -> string() | skip.
get_name(Line) ->
    case {is_message_line(Line), is_enum_line(Line)} of
        {true, false} ->
            %% Get Name from: 'message Name {'
            re:replace(Line, "message\\s*|{|\\s*", "", [{return, list}, global]);
        {false, true} ->
            %% Get Name from: 'enum Name {'
            re:replace(Line, "enum\\s*|{|\\s*", "", [{return, list}, global]);
        {false, false} ->
            skip
    end.

-spec is_code_line(string()) -> true | false.
is_code_line(Line) ->
    case re:run(Line, "//\\s*\\*>\\s*([a-zA-Z])+\\s*=\\s*([0-9])+\\s*", [{capture, first, list}]) of
        {match, _} -> true;
        _ -> false
    end.

-spec is_message_line(string()) -> true | false.
is_message_line(Line) ->
    case re:run(Line, "\\s*message\\s*([a-zA-Z0-9])+\\s*{", [{capture, first, list}]) of
        {match, _} -> true;
        _ -> false
    end.

-spec is_enum_line(string()) -> true | false.
is_enum_line(Line) ->
    case re:run(Line, "\\s*enum\\s*([a-zA-Z0-9])+\\s*{", [{capture, first, list}]) of
        {match, _} -> true;
        _ -> false
    end.

-spec is_package_line(string()) -> true | false.
is_package_line(Line) ->
    case re:run(Line, "\\s*package\\s*([a-zA-Z0-9.])+\\s*", [{capture, first, list}]) of
        {match, _} -> true;
        _ -> false
    end.

-spec is_category_line(string()) -> true | false.
is_category_line(Line) ->
    case re:run(Line, "//\\s*\\+>\\s*category\\s*=\\s*([a-zA-Z])+\\s*", [{capture, first, list}]) of
        {match, _} -> true;
        _ -> false
    end.

%% === Define Module
make_module(ModuleName) ->
    "" ++
        "-module(" ++ ModuleName ++ ").\n\n"
        "-export([encode/2]).\n"
        "-export([decode/1]).\n\n"
        "%%\n"
        "%% Frame Format:\n"
        "%%\n"
        "%% <-1 Byte->\n"
        "%% +--------+-------+----------------+\n"
        "%% |  Frame Length  |    BodyCode    |\n"
        "%% +--------+-------+----------------+\n"
        "%% |  Flags | RSRVD |      TID       |\n"
        "%% +--------+-------+----------------+\n"
        "%% |                                 |\n"
        "%% +               Body              |\n"
        "%% |                                 |\n"
        "%% +---------------------------------+\n"
        "%%\n\n".

%% === Define Definition
make_difinitions() ->
    "" ++
        "-define(FRAME_BIT_HEADER,   80).\n"
        "-define(FRAME_BIT_LENGTH,   32).\n"
        "-define(FRAME_BIT_CODE,     16).\n"
        "-define(FRAME_BIT_FLAGS,    8).\n"
        "-define(FRAME_BIT_RESERVED, 8).\n"
        "-define(FRAME_BIT_TRACKING, 16).\n"
        "\n"
        "-define(FRAME_BYTE_HEADER,   10).\n"
        "-define(FRAME_BYTE_LENGTH,   4).\n"
        "-define(FRAME_BYTE_CODE,     2).\n"
        "-define(FRAME_BYTE_FLAGS,    1).\n"
        "-define(FRAME_BYTE_RESERVED, 1).\n"
        "-define(FRAME_BYTE_TRACKING, 2).\n\n".

%% === Define Types
make_types() ->
    "" ++
        "-type category()      :: 'REQUEST' | 'REPLY' | 'SIGNAL' | 'REFLECT'.\n"
        "-type frame()         :: binary().\n"
        "-type stream()        :: binary().\n"
        "-type stream_rest()   :: binary().\n"
        "-type tid()           :: non_neg_integer().\n"
        "-type proto_obj()     :: tuple().\n"
        "-type decoded_objs()  :: [{proto_obj(), tid(), category()}].\n\n"
        .

%% === Encoder Functions:
-spec make_encoders(list()) -> string().
make_encoders(Params) ->
    Pred = fun([{file_name, FileName},
                {category,  Category},
                {package,    Package} | CodeName], ACC0) ->
                   lists:foldl(fun({C, N}, ACC) ->
                                       TermName = Package ++ "." ++ N,
                                       Encoder = FileName,
                                       ACC ++
                                           "encode(Term, TID) when element(1, Term) =:= '" ++ TermName ++ "' -> \n"
                                           "    Body  = " ++ Encoder ++ ":encode_msg(Term),\n"
                                           "    Frame = encode_frame(Body, TID, " ++ C ++ ", '" ++ Category ++"'),\n"
                                           "    {ok, Frame, TID};\n"
                               end, ACC0, CodeName)
           end,
    CommentAndSpec =
        "%% === Convert Record to Frame.\n"
        "%% === @NOTIC:\n"
        "%% === It will crash if it couldn't encode record to binary,\n"
        "%% === so you can use Try/Catch when call this function!\n"
        "-spec encode(proto_obj(), tid()) -> {ok, frame(), tid()} | {error, unknown_obj}.\n",
    lists:foldl(Pred, CommentAndSpec, Params) ++
        "encode(_, _) ->\n"
        "    {error, unknown_obj}.\n\n"
        "encode_frame(Body, TID, Code, Category) ->\n"
        "    Flags = encode_flag(Category),\n"
        "    Len = ?FRAME_BYTE_HEADER + byte_size(Body),\n"
        "    Header = <<Len:?FRAME_BIT_LENGTH,\n"
        "               Code:?FRAME_BIT_CODE,\n"
        "               Flags:?FRAME_BIT_FLAGS,\n"
        "               0:?FRAME_BIT_RESERVED,\n"
        "               TID:?FRAME_BIT_TRACKING>>,\n"
        "    <<Header/binary, Body/binary>>.\n\n"
        "-spec encode_flag(category()) -> 1 | 2 | 3 | 4.\n"
        "encode_flag('REQUEST') -> 1;\n"
        "encode_flag('REPLY')   -> 2;\n"
        "encode_flag('SIGNAL')  -> 3;\n"
        "encode_flag('REFLECT') -> 4.\n\n".

%% === Decoder Functions:
-spec make_decoders(list()) -> string().
make_decoders(Params) ->
    Pred = fun([{file_name, FileName},
                {category, _Category},
                {package,    Package} | CodeName], ACC0) ->
                   lists:foldl(fun({C, N}, ACC) ->
                                       TermName = Package ++ "." ++ N,
                                       Decoder = FileName,
                                       ACC ++
                                           "decode_body(" ++ C ++ ", Flags, TID, Body) ->\n"
                                           "    Category = decode_flag(Flags),\n"
                                           "    Term = " ++ Decoder ++ ":decode_msg(Body, '" ++ TermName ++ "'),\n"
                                           "    {ok, Term, TID, Category};\n"
                               end, ACC0, CodeName)

           end,

    "" ++
        "%% === Convert binary stream to record.\n"
        "%% === @NOTIC:\n"
        "%% === It will crash if it couldn't decode stream to records,\n"
        "%% === so you can use Try/Catch when call this function!\n"
        "-spec decode(stream()) -> {ok, stream_rest(), decoded_objs()}.\n"
        "decode(Stream) ->\n"
        "    parse_buffer(Stream, []).\n\n"
        "parse_buffer(Stream, Frames) ->\n"
        "    case byte_size(Stream) >= ?FRAME_BYTE_LENGTH of\n"
        "        true -> \n"
        "            <<Length:?FRAME_BIT_LENGTH, _/binary>> = Stream,\n"
        "            case byte_size(Stream) >= Length of\n"
        "                true ->\n"
        "                    <<Frame:Length/binary, StreamRest/binary>> = Stream,\n"
        "                    {ok, Term, TID, Category} = decode_frame(Frame),\n"
        "                    parse_buffer(StreamRest, Frames ++ [{Term, TID, Category}]);\n"
        "                false ->\n"
        "                    {Stream, Frames}\n"
        "            end;\n"
        "        false ->\n"
        "            {Stream, Frames}\n"
        "    end.\n\n"
        "decode_frame(<<_Length:?FRAME_BIT_LENGTH,\n"
        "               Code:?FRAME_BIT_CODE,\n"
        "               Flags:?FRAME_BIT_FLAGS,\n"
        "               _Reserved:?FRAME_BIT_RESERVED,\n"
        "               TID:?FRAME_BIT_TRACKING,\n"
        "               Body/binary>>) ->\n"
        "    decode_body(Code, Flags, TID, Body).\n\n" ++
        lists:foldl(Pred, "", Params) ++
        "decode_body(_, _, _, _) -> {error, unknown_body}.\n\n"
        "-spec decode_flag(1 | 2 | 3 | 4) -> category().\n"
        "decode_flag(1) -> 'REQUEST';\n"
        "decode_flag(2) -> 'REPLY';\n"
        "decode_flag(3) -> 'SIGNAL';\n"
        "decode_flag(4) -> 'REFLECT'.\n\n".
