###* 
  Re-direct some RPC calls to BitShares-JS.  Only enabled only if ./vendor/js/bts.js is present.
###
class BitsharesJsRpc
    
    constructor: (@RpcService, @q) ->
        return unless window.bts
        console.log "[BitShares-JS] enabled\t",window.bts
        @wallet_api = new window.bts.client.WalletAPI()
        @rpc_service_request = @RpcService.request
        @RpcService.request = @request # proxy requests
        
    request: (method, params, error_handler) =>
        method = switch method
            when 'get_info'
                'wallet_' + method
            else
                method
        fun = (=>
            prefix_index = method.indexOf('_')
            return null if prefix_index is -1
            api_group = method.substring 0, prefix_index
            api_function = method.substring(prefix_index + 1)
            switch api_group
                when 'wallet'
                    @wallet_api[api_function]
        )()
        defer = @q.defer()
        if fun
            ret = null
            err = null
            try
                ret = fun.apply(@wallet_api, params)
                ret = null if ret is undefined
                defer.resolve result:ret
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
                console.log '[BitShares-JS] intercept\t', method, params,'return',ret,'error',err
        else
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
                console.log '[BitShares-JS] pass-through\t', method, params,'return',ret,'error',err
        
        defer.promise

angular.module("app").service "BitsharesJsRpc", 
    ["RpcService", "$q", BitsharesJsRpc]

angular.module("app").run (BitsharesJsRpc, RpcService)->
    #console.log "[BitShares-JS] included"