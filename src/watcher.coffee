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
  elementsWithAttribute = (attribute, scope) ->
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
    ###*
    # An initialization function for your components. Components are marked by the presence of a `data-wt` attribute
    # (or whatever attribute you've configured for your `Watcher` instance), and their name is the value of this
    # attribute.
    #
    # You're encouraged to structure your application such that the name uniquely describes how to initialize the
    # component.
    #
    # @example
    #   new Watcher(function (name, el) {
    #     initializer = require('components/' + name);
    #     return initializer(el);
    #   }).observe();
    #   // Adding `<div data-wt='foo' />` to the DOM would cause this function to be invoked with name 'foo'.
    #
    # @callback initializeCallback
    # @param {string} name - The name of the component being initialized, i.e. the value of the data-wt attribute.
    # @param {Element} el - The root element of the component being initialized, i.e. the element with a data-wt
    #   attribute.
    # @return {Promise|object} A controller object for this component, or a promise resolving with that object. This
    #   controller will be returned (as a promise) from the `initialize` method on your watcher instance, and passed
    #   to the teardown callback that you specify.
    ###

    ###*
    # @param {initializeCallback} initialize - The function to initialize your components
    ###
    constructor: (initialize, options = {}) ->
      unless typeof(initialize) == 'function'
        throw new TypeError('invalid initialization function')
      @_options =
        attribute:        'data-wt'               # Set this attribute to denote an initializable block in the DOM
        throttle:         200                     # Minimum time to wait between successive DOM scans when observing
        poll:             1000                    # The interval to poll the DOM if observing when MutationObserver is not present
        root:             window.document.body    # The root element to scan and watch for changes
        Promise:          window.Promise          # Override to replace the Promise implementation
        MutationObserver: window.MutationObserver # Override to replace the MutationObserver implementation
      @_options[k] = v for own k, v of options
      @_instanceId = watcherCount++
      @_initialize = initialize

      unless isElement(@_options.root)
        throw new Error('options.root must be an HTML element (document.body may not be defined yet?)')
      unless @_options.Promise?
        throw new Error('options.Promise is not defined')

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
        el._watcherControllers[@_instanceId] = new @_options.Promise (resolve) =>
          resolve @_initialize(name, el)

      el._watcherControllers[@_instanceId]

    # Scan the DOM immediately, and initialize any uninitialized blocks. Returns a promise that resolves when all
    # blocks currently in the DOM have been initialized.
    scan: =>
      # Initialize all elements, no-op if they've already been initialized
      @_options.Promise.all (@initialize(el) for el in elementsWithAttribute(@_options.attribute, @_options.root))

    observe: =>
      # Adapted from Underscore's _.throttle
      throttledScan = ((func, wait) =>
        _now = -> new Date().getTime()
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

      )((=> @scan()), @_options.throttle)

      if @_options.MutationObserver?
        unless @_observer?
          @scan() # Scan once right away.

          handleMutation = (records) =>
            broken = false # Bail as early as possible
            for record in records
              unless broken
                for addedNode in record.addedNodes
                  if hasAttribute(addedNode, @_options.attribute) || elementsWithAttribute(@_options.attribute, addedNode).length > 0
                    throttledScan()
                    broken = true
                    break

          @_observer = new @_options.MutationObserver handleMutation
          @_observer.observe @_options.root , childList: true, subtree: true
      else if @_options.poll
        unless @_interval
          @scan()
          @_interval = setInterval (=> @scan()), @_options.poll
      else
        throw new Error('options.MutationObserver or options.poll must be set')
      this

    disconnect: =>
      @_observer?.disconnect()
      @_observer = undefined

      if @_interval
        clearInterval @_interval
        @_interval = undefined