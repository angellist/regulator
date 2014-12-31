((root, factory) ->
  if typeof define is 'function' and define.amd
    # AMD. Register as an anonymous module.
    define factory
  else
    # Browser globals.
    root.Watcher = factory()
) this, ->

  watcherCount = 0

  ## Polyfills and other old browser support

  # Check if the object is an HTML element. From
  # http://stackoverflow.com/questions/384286/javascript-isdom-how-do-you-check-if-a-javascript-object-is-a-dom-object
  isElement = (object) ->
    if typeof HTMLElement is 'object' # DOM2
      object instanceof HTMLElement
    else # Older browsers.
      object && typeof(object) is 'object' && object isnt null && object.nodeType is 1 && typeof object.nodeName is 'string'

  # Equivalent to $("[#{attribute}]", scope)
  elementsWithAttribute = (attribute, scope = document) ->
    unless isElement(scope) || scope.nodeType == 9 # 9 is the document node
      return []

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
    constructor: (getInitializer, options = {}) ->
      @_options =
        attribute:            'data-watcher-name' # Set this attribute to denote an initializable block in the DOM
        throttle:             200                 # Minimum time to wait between successive DOM scans
        promiseShim:          Promise             # Override to replace the Promise implementation
        mutationObserverShim: MutationObserver    # Override to replace the MutationObserver implementation
      @_options[k] = v for own k, v of options
      @_instanceId = watcherCount++
      @_initializers = {}
      @_getInitializer = getInitializer

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

        @_initializers[name] ||= @_getInitializer(name)

        promise = @_options.promiseShim.resolve(@_initializers[name]).then (initializer) -> initializer(el)
        el._watcherControllers[@_instanceId] = promise
        promise.catch (error) => @onError(error, name, el)

        el._watcherControllers[@_instanceId] = promise

      el._watcherControllers[@_instanceId]

    # Scan the DOM immediately, and initialize any uninitialized blocks. Returns a promise that resolves when all
    # blocks currently in the DOM have been initialized.
    scan: =>
      # Initialize all elements, no-op if they've already been initialized
      @_options.promiseShim.all (@initialize(el) for el in elementsWithAttribute(@_options.attribute))

    observe: =>
      unless @_options.mutationObserverShim?
        throw new Error('MutationObserver is not defined. Provide a shim if you need to support older browsers')
      unless @_observer?
        @scan() # Scan once right away.
        @_observer = new @_options.mutationObserverShim @_handleMutation
        @_observer.observe document.getElementsByTagName('body')[0] , childList: true, subtree: true
      this

    disconnect: =>
      @_observer?.disconnect()
      @_observer = null

    onError: (error, name, el) ->
      # Break out of the promise context
      setTimeout (-> throw error), 0

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

    # Adapted from Underscore's _.throttle.
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
