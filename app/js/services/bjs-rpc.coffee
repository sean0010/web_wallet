###* 
  Re-direct some RPC calls to BitShares-JS.  Only enabled only if ./vendor/js/bts.js is present.
###
class BitsharesJsRpc
    
    constructor: (@RpcService, @q) ->
        return unless window.bts
        console.log "[BitShares-JS] enabled\t",window.bts
        @wallet_api = new window.bts.client.WalletAPI null, @RpcService
        @rpc_service_request = @RpcService.request
        @RpcService.request = @request # proxy requests
        @log_hide=
            wallet_get_info: on
            blockchain_get_security_state:on
            get_config:on
        
    request: (method, params, error_handler) =>
        if method is 'execute_command_line'
            params = params[0]
            i = params.indexOf ' '
            if i isnt -1
                method = params.substring 0, i
                # parameters by space with optional double quotes
                params = params.substring(i+1).match /\w+|"[^"]+"/g #/\w+|"(?:\\"|[^"])+"/g
                for i in [0...params.length] by 1
                    p = params[i]
                    p = p.replace /^"/, ''
                    p = p.replace /"$/, ''
                    params[i] = p
            else
                method = params
                params = ""
                
        method = switch method
            when 'get_info'
                'wallet_' + method
            else
                method
        
        api_group = null
        fun = (=>
            prefix_index = method.indexOf '_'
            return null if prefix_index is -1
            api_group = method.substring 0, prefix_index
            api_function = method.substring prefix_index + 1
            switch api_group
                when 'wallet'
                    @wallet_api[api_function]
        )()
        log_intercept= =>
            console.log "[BitShares-JS] #{api_group}\tintercept\t", method, params,'return',ret,'error',err unless @log_hide[method]
        
        defer = @q.defer()
        if fun #and false
            ret = null
            err = null
            promise = null
            try
                ret = fun.apply(@wallet_api, params)
                ret = null if ret is undefined
                if ret?["then"]
                    promise = ret
                else
                    ret = null if ret is undefined
                    defer.resolve result:ret
            catch error
                err = error
                error = message:error unless error.message
                if error.message.match /wallet.not_found/
                    navigate_to("createwallet") unless window.location.hash == "#/createwallet"
                else if error.message.match /wallet.must_be_opened/
                    unless window.location.hash == "#/createwallet"
                        navigate_to("unlockwallet") unless window.location.hash == "#/unlockwallet"
                else
                    defer.reject data:error:error.message
            finally
                log_intercept() unless promise
            
            if promise
                console.log 'promise',method
                ret.then(
                    (result)->
                        ret = result
                        ret = null if ret is undefined
                        defer.resolve result:ret
                        log_intercept()
                    (error)->
                        err = error
                        error = message:error unless error.message
                        defer.reject data:error:error.message
                        log_intercept()
                ).done()
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
                console.log "[BitShares-JS] #{api_group}\tpass-through\t", method, params,'return',ret?.result,'error',err unless @log_hide[method]
        
        defer.promise

angular.module("app").service "BitsharesJsRpc", 
    ["RpcService", "$q", BitsharesJsRpc]

angular.module("app").run (BitsharesJsRpc, RpcService)->
    #console.log "[BitShares-JS] included"