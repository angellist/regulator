((root, factory) ->
  if typeof define is 'function' and define.amd
    # AMD. Register as an anonymous module.
    define factory
  else
    # Browser globals.
    root.Watcher = factory()
) this, ->

  watcherCount = 0

  # Polyfills if needed
  elementsWithAttribute = (attribute, scope = document) ->
    if scope.querySelectorAll?
      scope.querySelectorAll "[#{attribute}]"
    else # IE < 8
      # http://stackoverflow.com/questions/9496427/can-i-get-elements-by-attribute-selector-when-queryselectorall-is-not-available
      el for el in scope.getElementsByTagName('*') when el.getAttribute(attribute)?

  hasAttribute = (el, attribute) ->
    if el.hasAttribute?
      el.hasAttribute attribute
    else # IE < 9
      # https://gist.github.com/Phinome/f21a01ae4fa35b371499
      typeof el[attribute] isnt 'undefined'

  class Watcher
    constructor: (options = {}) ->
      @_options =
        attribute:            'data-watcher-name' # Set this attribute to denote an initializable block in the DOM
        throttle:             200                 # Minimum time to wait between successive DOM scans
        promiseShim:          Promise             # Override to replace the promise implementation
        mutationObserverShim: MutationObserver
      @_options[k] = v for own k, v of options
      @_instanceId = watcherCount++
      @_initializers = {}

      unless @_options.promiseShim?
        throw new Error('Promise is not defined. Provide a shim if you need to support older browsers.')


    # Initialize the element (if it hasn't been initialized already) and return a promise resolving to the element's
    # controller (e.g. the return value of its initialization function).
    initialize: (el) =>
      unless hasAttribute el, @_options.attribute
        throw new Error("Element must have a #{@_options.attribute} attribute")

      # Store controllers from this and other Watcher instances on the element.
      el._watcherControllers ||= {}

      # Store the controller for this instance and return it.
      unless el._watcherControllers[@_instanceId]?
        name = el.getAttribute @_options.attribute

        @_initializers[name] ||= @initializer(name)

        #@_options.promiseShim.resolve(@_initializers[name]).then((initializer) -> throw new Error('here') ; initializer(el)).catch -> console.log('here')

        promise = @_options.promiseShim.resolve(@_initializers[name]).then (initializer) -> initializer(el)
        el._watcherControllers[@_instanceId] = promise
        promise.catch (error) => @onError(error, name, el)

        el._watcherControllers[@_instanceId] = promise

      el._watcherControllers[@_instanceId]

    # Retrieve a function to initialize DOM blocks with the given name. When a block with name "foo" is added to the
    # DOM, initializer("foo") will be called with that block's root as the only argument. By default, delegates to the
    # "initializer" option that was passed in at construction. Subclasses may also simply override this function.
    # May return a promise resolving to the initializer, instead of the initializer itself.
    initializer: (name) ->
      unless typeof @_options.initializer is 'function'
        throw new Error('Must set options.initializer or override the initializer method')
      @_options.initializer(name)

    # Scan the DOM immediately, and initialize any uninitialized blocks. Returns a promise that resolves when all
    # blocks currently in the DOM have been initialized.
    scan: =>
      # Initialize all elements, no-op if they've already been initialized
      @_options.promiseShim.all (@initialize(el) for el in elementsWithAttribute(@_options.attribute))

    observe: =>
      unless @_options.mutationObserverShim?
        throw new Error('MutationObserver is not defined. Provide a shim if you need to support older browsers')
      unless @_observer?
        @_observer = new @_options.mutationObserverShim @_handleMutation
        @_observer.observe document.getElementsByTagName('body')[0] , childList: true, subtree: true
      this

    disconnect: =>
      @_observer?.disconnect()
      @_observer = null

    onError: (error, name, el) -> throw error

    ## Protected methods - probably no need to change these.

    # When the MutationObserver set up by "observe" is triggered
    _handleMutation: (records) =>
      broken = false # Bail as early as possible
      for record in records
        unless broken
          for addedNode in record.addedNodes
            if hasAttribute(addedNode, @_options.attribute) || elementsWithAttribute(@_options.attribute, addedNode).length > 0
              @_throttledScan()
              broken = true
              break

    # Adapted from Underscore's `_.throttle`.
    _throttledScan: =>
      # Use an inner function so that successive calls are properly tracked without having to assign a ton of instance
      # variables to the watcher. This is roughly equivalent to
      # `@_throttledScanFn ||= _.throttle(@scan, @_options.throttle)`
      @_throttledScanFn ||= ((func, wait) =>
        _now = Date.now || -> new Date().getTime()
        timeout = null
        previous = 0

        later = =>
          previous = _now()
          timeout = null
          func()

        =>
          now = _now()
          remaining = wait - (now - previous)
          if remaining <= 0 || remaining > wait

            # In case we're still waiting on a setTimeout call
            clearTimeout timeout
            timeout = null

            previous = now
            func()
          else
            unless timeout
              timeout = setTimeout later, remaining
      )(@scan, @_options.throttle)

      @_throttledScanFn()
      this
