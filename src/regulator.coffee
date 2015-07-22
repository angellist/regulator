((root, factory) ->
  if typeof define is 'function' and define.amd
    # AMD. Register as an anonymous module.
    define factory
  else
    # Browser globals.
    root.Regulator = factory()
) this, ->

  regulatorCount = 0

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

  ###*
  # @typedef {Object} Regulator.Controller
  #
  # @description
  # An object returned by a {@link Regulator.Strategy} implementation, which becomes associated with a component on the
  # page. Controllers are accessible any time through {@link Regulator#withController} or {@link Regulator#initialize}.
  ###

  ###*
  # @callback Regulator.Strategy
  #
  # @description
  # An initialization strategy for your components. You're encouraged to structure your application such that the
  # name uniquely describes how to initialize the component.
  #
  # @example
  # new Regulator(function (name, el) {
  #   initializer = require('components/' + name);
  #   return initializer(el);
  # }).observe();
  # // Adding "<div data-rc='foo' />" to the DOM would cause this function to be invoked with name "foo".
  #
  # @param {String} name The name of the component being initialized, i.e. the value of the <code>data-rc</code>
  #   attribute.
  # @param {Element} element The root element of the component being initialized, i.e. the element with a
  #   <code>data-rc</code> attribute.
  # @return {Promise|Regulator.Controller} A controller object to associate with the component, which will be globally
  #   available through the {@link Regulator#initialize} and {@link Regulator#withController} functions. May also
  #   return a <code>Promise</code> object if you wish to build the controller asynchronously.
  ###

  ###*
  # @callback Regulator.ControllerCallback
  #
  # @description
  # A callback function for {@link Regulator#withController}.
  #
  # @param {Regulator.Controller} controller The controller for a component.
  ###

  ###*
  # @class Regulator
  #
  # @param {Regulator.Strategy} strategy The function to initialize your components.
  # @param {Object} [options]
  # @param {String} [options.attribute='data-rc'] The attribute to denote the root of a component in the DOM.
  # @param {Number} [options.throttle=200] When observing the DOM for changes with <code>MutationObserver</code>,
  #   the minimum interval (in milliseconds) between successive scans.
  # @param {Number} [options.poll=1000] The interval (in milliseconds) to poll the DOM for changes if
  #   <code>MutationObserver</code> is not available.
  # @param {Element} [options.root=window.document.body] The root element to scan for components. Elements outside this
  #   root will be ignored by {@link Regulator#scan} and {@link Regulator#observe}.
  # @param {Function} [options.Promise=window.Promise] The {@link https://promisesaplus.com/|Promises/A+}
  #   implementation to use.
  # @param {Function} [options.MutationObserver=window.MutationObserver] The
  #   {@link https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver|MutationObserver} implementation to use
  #   when invoking {@link Regulator#observe}. If no implementation is provided, a polling fallback is used.
  ###
  class Regulator
    constructor: (strategy, options = {}) ->
      unless typeof(strategy) == 'function'
        throw new TypeError('invalid initialization function')
      @_options =
        attribute:        'data-rc'
        throttle:         200
        poll:             1000
        root:             window.document.body
        Promise:          window.Promise
        MutationObserver: window.MutationObserver
      @_options[k] = v for own k, v of options
      @_instanceId = regulatorCount++
      @_strategy = strategy

      unless isElement(@_options.root)
        throw new Error('options.root must be an HTML element (document.body may not be defined yet?)')
      unless @_options.Promise?
        throw new Error('options.Promise is not defined')

    ###*
    # @function Regulator#initialize
    #
    # @description
    # Invoke our {@link Regulator.Strategy} callback to initialize a component.
    #
    # @param {Element} element The root of a component on the page. Must have a non-empty <code>data-rc</code>
    #   attribute (or whatever attribute you specified when creating the {@link Regulator}).
    # @return {Promise} A promise resolving to the {@link Regulator.Controller} associated with the component.
    ###
    initialize: (element) =>
      unless hasAttribute element, @_options.attribute
        throw new Error("Element must have a #{@_options.attribute} attribute")

      # Store controllers from this and other Regulator instances on the element.
      element._regulatorControllers ||= {}

      # Store the controller for this instance and return it.
      unless element._regulatorControllers[@_instanceId]?
        name = element.getAttribute @_options.attribute
        element._regulatorControllers[@_instanceId] = new @_options.Promise (resolve) =>
          resolve @_strategy(name, element)

      element._regulatorControllers[@_instanceId]

    ###*
    # @function Regulator#scan
    #
    # @description
    # Immediately initialize any uninitialized components on the page.
    #
    # @return {Promise} A promise which resolves when all components have been initialized.
    ###
    scan: =>
      # Initialize all elements, no-op if they've already been initialized
      @_options.Promise.all (@initialize(el) for el in elementsWithAttribute(@_options.attribute, @_options.root))

    ###*
    # @function Regulator#observe
    #
    # @description
    # Watch the page for changes, and initialize components as they're added.
    #
    # @return {Regulator} This {@link Regulator} instance.
    ###
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

    ###*
    # @function Regulator#withController
    #
    # @description
    # Initialize the given components, and invoke the callback with each of their
    #   {@link Regulator.Controller|controllers}.
    #
    # @param {Element|Element[]} elements The root element(s) of the component(s) to be initialized.
    # @param {Regulator.ControllerCallback} callback The callback to invoke with the controller for each element.
    ###
    withController: (elements, callback) =>
      if isElement(elements)
        elements = [elements]
      @_options.Promise.all (@initialize(el).then(callback) for el in elements)

    ###*
    # @function Regulator#disconnect
    #
    # @description
    # Stop watching the page for changes after a call to {@link Regulator#observe}.
    #
    # @return {Regulator} This {@link Regulator} instance.
    ###
    disconnect: =>
      @_observer?.disconnect()
      @_observer = undefined

      if @_interval
        clearInterval @_interval
        @_interval = undefined
      this