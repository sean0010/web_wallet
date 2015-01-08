angular.module("app").controller "CreateWalletController", ($scope, $rootScope, $rootElement, $modal, $log, $location, $idle, RpcService, Wallet, Growl) ->
    $rootScope.splashpage = true

    $idle.unwatch()

    $scope.wallet_name = "default"
    $scope.spending_password = ""
    $scope.descriptionCollapsed = true

    $scope.submitForm = (isValid, password) ->
        if isValid
            promise = Wallet.create($scope.wallet_name, password)
            promise.then ->
                $location.path("/create/account")
            $rootScope.showLoadingIndicator promise
        else
            Growl.error "", "Unable to create a wallet. Please fill up the form below."

    $scope.$on "$destroy", ->
        $rootScope.splashpage = false
        $scope.startIdleWatch()

    $scope.light_weight_enabled =
        window.bts and bts.wallet.Wallet.has_secure_random()
       
    # Small visual sample of what is going on...
    $scope.entropy = ""
    $scope.entropy_collection = $scope.light_weight_enabled
    private_entropy = []
    public_entropy = []
    chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    chars_length = chars.length
    on_mouse_event = (event) ->
        #console.log event.type, event
        return unless $scope.entropy_collection
        return unless $scope.license_accepted
        if private_entropy.length >= 1000
            $scope.$apply ->
                $scope.entropy_collection = off
            bts.wallet.Wallet.add_entropy private_entropy.join('')
            private_entropy.length = 0
            return
        
        num = (X,Y) ->
            time = new Date().getTime()
            Math.pow(X, 4) +
            Math.pow(Y, 4) +
            Math.floor(time * 1000) +
            Math.floor(Math.random() * 10000000000000)
        private_entropy.push i = num event.pageX, event.pageY
        private_entropy.push num event.clientX, event.clientY
        private_entropy.push num event.offsetX, event.offsetY
        private_entropy.push num event.screenX, event.screenY
        private_entropy.push event.force if event.force
        if public_entropy.length < 40
            if new Date().getTime() % 3 == 0
                public_entropy.push chars.charAt(i % chars_length)
        else
            public_entropy = public_entropy.slice 1
            public_entropy.push chars.charAt(i % chars_length)
        $scope.$apply ->
            $scope.entropy = public_entropy.join('')
    $rootElement.on 'mousemove', (event) ->
        on_mouse_event event
    $rootElement.on 'touchmove', (event) ->
        #console.log event
        on_mouse_event event.originalEvent.changedTouches[0] 
