###* 
  Re-direct some RPC calls to BitShares-JS.  Only enabled only if ./vendor/js/bts.js is present.
###
class BitsharesJsRpc
    
    constructor: (@RpcService, @q) ->
        return unless window.bts
        console.log "[BitShares-JS] enabled\t"#,window.bts
        @wallet_api = new window.bts.client.WalletAPI null, @RpcService
        @rpc_service_request = @RpcService.request
        @RpcService.request = @request
        @log_hide=
            get_info: on
            wallet_get_info: on
            blockchain_get_security_state:on
            wallet_account_transaction_history: on
            get_config:on
        
        @aliases=((def)-># add aliases
            aliases = {}
            for method in def.methods
                if method.aliases
                    for alias in method.aliases
                        aliases[alias] = method.method_name
            aliases
        )(window.bts.client.WalletAPI.libraries_api_wallet)

    request: (method, params, error_handler) =>
        defer = @q.defer()
        ret = null
        err = null
        promise = null
        api_group = null
        
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
        
        method = ((m)->if m then m else method) @aliases[method]
        
        # function for local implementation
        fun = (=>
            prefix_index = method.indexOf '_'
            return null if prefix_index is -1
            api_group = method.substring 0, prefix_index
            api_function = method.substring prefix_index + 1
            switch api_group
                when 'wallet'
                    @wallet_api[api_function]
        )()
        
        handle_response=(intercept=true) =>
            unless @log_hide[method]
                ret_string = ""#JSON.stringify ret
                type = if intercept then "intercept" else "pass-through"
                console.log "[BitShares-JS] #{api_group}\t#{type}\t", method, params,'return:',ret,ret_string,'error:',(if err then err.stack else err)
            
            if err
                err = message:err unless err.message
                err = data:error: err
                defer.reject err
                error_handler err if error_handler
            else
                ret = null if ret is undefined
                defer.resolve result:ret
            
            return
        
        if not fun and method.match /^wallet_/
            err = 'Not Implemented'
            handle_response()
            return defer.promise
        
        if fun #and false #'and false' disable bitshares-js but keep logging
            try
                ret = fun.apply(@wallet_api, params)
                if ret?["then"]
                    promise = ret

            catch error
                err = error
                #error = message:error unless error.message
                if error.message.match /^wallet.not_found/
                    navigate_to("createwallet") unless window.location.hash == "#/createwallet"
                else if error.message.match /^wallet.must_be_opened/
                    unless window.location.hash == "#/createwallet"
                        navigate_to("unlockwallet") unless window.location.hash == "#/unlockwallet"
            finally
                handle_response() unless promise
            
            if promise
                console.log 'promise',method
                ret.then(
                    (result)->
                        ret = result
                        handle_response()
                        return
                    (error)->
                        err = error
                        handle_response()
                        return
                )
        else # proxy
            #console.log '[BitShares-JS] pass-through\t',method,params
            this_error_handler=(error)->
                err = error
                handle_response intercept=false
            try
                promise = @rpc_service_request method, params, this_error_handler
                promise.then(
                    (response)->
                        ret = response.result
                        handle_response intercept=false
                        return
                    (error)->
                        err = error
                        handle_response intercept=false
                        return
                )
            catch error
                err = error
                handle_response intercept=false
        
        defer.promise

angular.module("app").service "BitsharesJsRpc", 
    ["RpcService", "$q", BitsharesJsRpc]

angular.module("app").run (BitsharesJsRpc, RpcService)->
    #console.log "[BitShares-JS] included"