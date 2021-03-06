-module(cowboy_session_secure).
-export([generate/5, validate/4]).

%%
%% Based on work by Alex X. Liu and others: http://www.cse.msu.edu/~alexliu/publications/Cookie/cookie.pdf
%%

%%
%% WARNING: Please understand that there is no guarantee made about how secure this thing really is
%%          This code's author is clueless about cryptography and security
%%

generate(Data, SecData, SessionKey, CKey, IVec) ->
    EncData = crypto:aes_cbc_128_encrypt(CKey, IVec, pad(16,<<(size(Data)):1/big-signed-integer-unit:16,
                                                              Data/binary, 
                                                              (size(SecData)):1/big-signed-integer-unit:16,
                                                              SecData/binary>>)),
    Hmac = crypto:sha_mac([Data, EncData, SessionKey], CKey),
    base64:encode(<<(size(Data)):1/big-signed-integer-unit:16,
                    Data/binary,
                    (size(EncData)):1/big-signed-integer-unit:16,
                    EncData/binary,
                    (size(Hmac)):1/big-signed-integer-unit:16,
                    Hmac/binary>>).

validate(Cookie, SessionKey, CKey, IVec) ->
    <<DataLen:1/big-signed-integer-unit:16,
      Data:DataLen/binary,
      EncDataLen:1/big-signed-integer-unit:16,
      EncData:EncDataLen/binary,
      HmacLen:1/big-signed-integer-unit:16,
      Hmac:HmacLen/binary>>
        = base64:decode(Cookie),
    DecData = crypto:aes_cbc_128_decrypt(CKey, IVec, EncData),
    Mac = crypto:sha_mac([Data, EncData, SessionKey], CKey),
    case secure_compare(Mac, Hmac) of
        true ->
            case DecData of
                <<ResDataLen:1/big-signed-integer-unit:16, ResData:ResDataLen/binary,
                  ResSecDataLen:1/big-signed-integer-unit:16, ResSecData:ResSecDataLen/binary,
                  _Rest/binary>> ->
                    {ResData, ResSecData};
                _ ->
                    false
            end;
        false ->
            false
    end.
              
%% Internal
secure_compare(A,B) ->
    secure_compare(A,B,0).

secure_compare(<<>>,<<>>,0) ->
    true;
secure_compare(<<A:1/unit:8,AT/binary>>,
               <<B:1/unit:8,BT/binary>>,
               Acc) ->
    secure_compare(AT,BT, Acc bor (A bxor B));
secure_compare(_,_,_) ->
    false.

pad(Width, Binary) ->
    case ((Width - size(Binary) rem Width) rem Width) of
        0 -> Binary;
        N -> <<Binary/binary, 0:(N*8)>>
    end.
