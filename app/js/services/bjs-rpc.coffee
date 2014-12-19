###* 
  Re-direct some RPC calls to BitShares-JS.  Only enabled only if ./vendor/js/bts.js is present.
###
class BitsharesJsRpc
    
    constructor: (@RpcService, @q) ->
        return unless window.bts
        console.log "[BitShares-JS] enabled\t",window.bts
        @jwallet_api = new window.bts.wallet.WalletAPI()
        @rpc_service_request = @RpcService.request # proxy
        @RpcService.request = @request # proxy requests
        
    request: (method, params, error_handler) =>
        fun = (=>
            m = method.split '_', 2 # wallet open
            api_group = m[0]
            api_function = m[1]
            switch api_group
                when 'wallet'
                    @jwallet_api[api_function]
        )()
        defer = @q.defer()
        if fun
            ret = null
            err = null
            try
                ret = fun.apply(@, params)
                ret = null if ret is undefined
                defer.resolve data:result:ret
            catch error
                err = error
                error = message:error unless error.message
                switch error.message
                    when 'wallet.not_found'
                        navigate_to("createwallet") unless window.location.hash == "#/createwallet"
                    when 'wallet.must_be_opened'
                        unless window.location.hash == "#/createwallet"
                            navigate_to("unlockwallet") unless window.location.hash == "#/unlockwallet"
                    else
                        defer.reject
                            data:error:error.message
            finally
                console.log '[BitShares-JS] intercept\t', method, params,'return ->',ret,'error ->',err
        else # proxy
            #console.log '[BitShares-JS] pass-through\t',method,params
            ret = null
            err = null
            promise = @rpc_service_request method, params, error_handler
            promise.then(
                (result)=>
                    ret = result
                    defer.resolve result
                (error)=>
                    err = error
                    defer.reject error
            ).finally ()=>
                console.log '[BitShares-JS] pass-through\t', method, params,'return ->',ret,'error ->',err
        
        defer.promise

angular.module("app").service "BitsharesJsRpc", 
    ["RpcService", "$q", BitsharesJsRpc]

angular.module("app").run (BitsharesJsRpc, RpcService)->
    #console.log "[BitShares-JS] included"