define [
  'src/watcher'
], (Watcher) ->

  describeIfMutationObserver = (if window.MutationObserver? then describe else xdescribe)

  emptyFixture = '<div data-wt="empty"></div>'
  fullFixture = """
<div data-wt="full">
  <span>Test content</span>
</div>
"""

  nestedFixture = """
<div>
  <div data-wt="nested">Content</div>
</div>
"""

  doubleNestedFixture = """
<span id="nested-outer" data-wt="nested-outer">
  <div>Outer content</div>
  <strong id="nested-inner" data-wt="nested-inner">
    <span>Nested content</span>
  </strong>
</span>
"""
  deadFixture = '<span class="dead">No initialized content here</span>'

  describe Watcher, ->
    describe '#scan', ->
      beforeEach ->
        @watcher = new Watcher (->)
        spyOn(@watcher, 'initialize')

      it 'initializes all elements with data-wt set', ->
        fixtures = fixture.set emptyFixture, fullFixture, fullFixture
        @watcher.scan()
        expect(@watcher.initialize.calls.count()).toBe 3

        expect(fixtures.length).toBe 3 # Sanity
        for f in fixtures
          expect(f.length).toBe 1 # Sanity, make sure fixture.set returns an array of arrays
          expect(@watcher.initialize.calls.allArgs()).toContain f # Each argument list is also a one-element array

      it 'initializes elements nested within one another', ->
        fixture.set doubleNestedFixture
        @watcher.scan()
        expect(@watcher.initialize.calls.count()).toBe 2

        elements = (document.getElementById(id) for id in ['nested-inner', 'nested-outer'])

        expect(elements.length).toBe 2 # Sanity check
        for element in elements

          expect(typeof element).toBe('object') # Sanity check
          expect(@watcher.initialize.calls.allArgs()).toContain [element]

      it 'only initializes elements with the specified attribute', ->
        fixtures = fixture.set "<div data-other-thing='name' id='expected'>content</div>#{fullFixture}}"
        expect(fixtures.length).toBe 2 # Sanity

        @watcher = new Watcher (->), attribute: 'data-other-thing'
        spyOn @watcher, 'initialize'
        @watcher.scan()

        expect(@watcher.initialize.calls.count()).toBe 1, 'too many calls to initialize'
        expect(@watcher.initialize.calls.allArgs()).toContain [document.getElementById('expected')]

      it 'only initializes elements within the specified root', ->
        fixtures = fixture.set "<div id='root'>#{fullFixture}</div>#{nestedFixture}"
        expect(fixtures.length).toBe 2 # Sanity

        @watcher = new Watcher (->), root: document.getElementById('root')
        spyOn @watcher, 'initialize'
        @watcher.scan()

        expect(@watcher.initialize.calls.count()).toBe 1, 'too many calls to initialize'
        expect(@watcher.initialize.calls.allArgs()).toContain [document.getElementById('root').firstChild]

    describe '#initialize', ->
      class SynchronousWatcher extends Watcher
        constructor: (options = {})->
          super @initializer, options
          @allowedNames = ['empty', 'full', 'nested-inner', 'nested-outer']
          @invocationCounts = {}

          # If true, initializer functions will return a promise instead of a plain value. Note that this is different
          # from the case where initializer functions are retrieved asynchronously (see AsynchronousWatcher for that
          # case), and that these two cases are not mutually exclusive.
          @asyncInitialization = false
          @asyncInitializationInvoked = false

          # Allow testing errorsmf
          @throwErrorDuringInitialization = false

        initializer: (name, el) =>
          throw new Error("Unexpected root: #{name}") unless name in @allowedNames

          @invocationCounts[name] ||= 0
          @invocationCounts[name]++
          el.className = name

          # If appropriate...
          throwError = => throw new Error('Test error') if @throwErrorDuringInitialization
          ret = name: name

          # Return a promise that resolves with the return value
          if @asyncInitialization
            new Promise (resolve) =>
              throwError()
              setTimeout =>
                # Track this so we can use it to sanity check that the initialization was actually asynchronous
                @asyncInitializationInvoked = true
                resolve ret
              , 5
          # Return a value inline
          else
            throwError()
            ret

      class AsynchronousWatcher extends SynchronousWatcher
        initializer: (name) ->
          orig = super
          new Promise (resolve) =>
            setTimeout =>
              resolve orig
            , 5

      beforeEach ->
        @el = fixture.set(fullFixture)[0]

      sharedExamples = ->

        ###
        Invocation
        ###

        it 'invokes the initializer for the element on the first call', (done) ->
          # Sanity checks
          expect(@el.className).toBe ''
          expect(@watcher.invocationCounts['full']).toBeUndefined()

          @watcher.initialize(@el).then =>
            expect(@watcher.invocationCounts['full']).toBe 1
            expect(@el.className).toBe 'full'
            done()

        it 'does not invoke the initializer again on successive synchronous calls', (done) ->
          promise1 = @watcher.initialize(@el)
          @watcher.initialize(@el).then =>
            promise1.then =>
              expect(@watcher.invocationCounts['full']).toBe 1
              done()

        it 'does not invoke the initializer again on successive asynchronous calls', (done) ->
          @watcher.initialize(@el).then =>
            @watcher.initialize(@el).then =>
              expect(@watcher.invocationCounts['full']).toBe 1
              done()

        it 'invokes the initializer across multiple elements with the same root name', (done) ->
          fixtures = fixture.set fullFixture, fullFixture, fullFixture
          promises = (@watcher.initialize(f[0]) for f in fixtures)
          Promise.all(promises).then =>
            expect(@watcher.invocationCounts['full']).toBe 3
            done()

        ###
        Error handling and return values
        ###

        sharedErrorExamples = -> # Shared between the async/sync return value cases
          beforeEach ->
            @watcher.throwErrorDuringInitialization = true

          it 'allows initialization errors to be caught directly', (done) ->
            @watcher.initialize(@el).catch (error) =>
              expect(error.message).toBe 'Test error'
              done()

        describe 'when the initializer returns a synchronous value', ->
          it 'returns a promise which resolves to the initializer\'s synchronous return value', (done) ->
            @watcher.initialize(@el).then (resolvedValue) ->
              expect(resolvedValue).toEqual name: 'full'
              done()

          describe '(shared error examples)', sharedErrorExamples

        describe 'when the initializer returns an asynchronous value', ->
          beforeEach ->
            @watcher.asyncInitialization = true

          it 'returns a promise which resolves to the initializer\'s eventual value', (done) ->
            @watcher.initialize(@el).then (resolvedValue) =>
              expect(@watcher.asyncInitializationInvoked).toBe true # Sanity check
              expect(resolvedValue).toEqual name: 'full'
              done()
          describe '(shared error examples)', sharedErrorExamples

      describe 'with a synchronously generated initializer', ->
        beforeEach ->
          @watcher = new SynchronousWatcher
        describe '(shared examples)', sharedExamples


      describe 'with an asynchronously generated initializer', ->
        beforeEach ->
          @watcher = new AsynchronousWatcher
        describe '(shared examples)', sharedExamples

    describe '#observe', ->

      describe '(with a polling interval)', ->
        beforeEach ->
          jasmine.clock().install()
          @watcher = new Watcher (->),
            MutationObserver: null
            poll: 100
            throttle: 1000 # Set a large scan interval - the polling interval should ignore this
          spyOn(@watcher, 'scan')
          @watcher.observe()

        afterEach ->
          @watcher.disconnect()
          jasmine.clock().uninstall()

        it 'scans the DOM once immediately', ->
          expect(@watcher.scan.calls.count()).toBe 1

        it 'scans the DOM again after the polling interval has elapsed once', ->
          jasmine.clock().tick(99)
          expect(@watcher.scan.calls.count()).toBe 1
          jasmine.clock().tick(2)
          expect(@watcher.scan.calls.count()).toBe 2

        it 'continues scanning after the polling interval has elapsed more than once', ->
          jasmine.clock().tick(199)
          expect(@watcher.scan.calls.count()).toBe 2
          jasmine.clock().tick(2)
          expect(@watcher.scan.calls.count()).toBe 3

      describeIfMutationObserver '(with MutationObserver)', ->
        afterEach ->
          @watcher.disconnect()

        it 'returns the Watcher instance', ->
          @watcher = new Watcher (->)
          expect(@watcher.observe()).toBe @watcher

        describe '(behavior with various fixtures)', ->
          beforeEach ->
            @watcher = new Watcher (->)

          it 'invokes scan once immediately', ->
            spyOn(@watcher, 'scan')
            @watcher.observe()
            expect(@watcher.scan.calls.count()).toBe 1

          it 'scans the DOM when new root elements with data-wt are added', (done) ->
            fixtureAdded = false

            @watcher.observe()
            spyOn(@watcher, 'scan').and.callFake -> expect(fixtureAdded).toBe true ; done()

            fixture.set fullFixture
            fixtureAdded = true

          it 'scans the DOM when new nested elements with data-wt are added', (done) ->
            fixtureAdded = false

            @watcher.observe()
            spyOn(@watcher, 'scan').and.callFake -> expect(fixtureAdded).toBe true ; done()

            fixture.set nestedFixture
            fixtureAdded = true

        describe '(scanning only when appropriate)', ->
          beforeEach ->
            @mutationProcessed = ->
              throw new Error('Override this function to get a notification when mutations have been processed')

            # Need to wrap this so the actual function can be set dynamically in the tests
            mutationProcessedWrapper = =>
              @mutationProcessed()

            # Normal observer, except we invoke a definable callback whenever mutations are actually handled,
            # so that we can check to see what happened in the handler
            FakeObserver = class
              constructor: (callback) ->
                wrappedCallback = (args...) ->
                  ret = callback.apply this, args
                  mutationProcessedWrapper()
                  ret
                @mutationObserver = new MutationObserver(wrappedCallback)
              observe: (target, opts) => @mutationObserver.observe(target, opts)
              disconnect: => @mutationObserver.disconnect()

            @watcher = new Watcher((->), MutationObserver: FakeObserver)
            @watcher.observe()

            spyOn(@watcher, 'scan')

          it '(sanity check) scans the DOM when relevant elements are added', (done) ->
            # Just a sanity check test to make sure our fake observer is behaving appropriately
            expect(@watcher.scan.calls.count()).toBe 0 # Paranoia
            @mutationProcessed = =>
              expect(@watcher.scan.calls.count()).toBe 1
              done()
            fixture.set fullFixture

          it 'does not scan the DOM when irrelevant elements are added', (done) ->
            @mutationProcessed = =>
              expect(@watcher.scan.calls.count()).toBe 0
              done()

            fixture.set deadFixture

          it 'does not scan the DOM when text nodes are added', (done) ->
            @mutationProcessed = =>
              expect(@watcher.scan.calls.count()).toBe 0
              done()

            fixture.el.innerHTML = 'Text node'

        describe '(throttling the scan call)', ->
          beforeEach ->
            jasmine.clock().install().mockDate()

            storedHandler = null

            # Dummy observer that allows a single global callback to be invoked at any time
            FakeObserver = class
              constructor: (handler) ->
                @handler = handler
              observe: ->
                throw new Error('Shouldn\'t create more than one of these') if storedHandler?
                storedHandler = @handler
              disconnect: ->
                storedHandler = null

            # Invoke the callback with a records object that contains relevant new nodes.
            # See the spec at https://developer.mozilla.org/en-US/docs/Web/API/MutationObserver
            @triggerScan = =>
              # Create a temporary real observer to make sure we're passing in the appropriate record list object
              observer = new MutationObserver(->)
              observer.observe(fixture.el, subtree: true, childList: true)
              fixture.set fullFixture, true
              records = observer.takeRecords()
              observer.disconnect()

              throw new Error('Unexpected: observer did not find new records') if records.length != 1

              # Invoke the shim handler
              storedHandler records

            @watcher = new Watcher (->), throttle: 100, MutationObserver: FakeObserver
            @watcher.observe()

            spyOn(@watcher, 'scan')

          afterEach ->
            jasmine.clock().uninstall()

          it 'invokes scan immediately when called once', ->
            @triggerScan()
            expect(@watcher.scan.calls.count()).toBe 1
          it 'does not invoke scan immediately when called twice', ->
            @triggerScan()
            @triggerScan()
            expect(@watcher.scan.calls.count()).toBe 1

          it 'invokes scan at the end of the throttle interval when invoked repeatedly', ->
            @triggerScan()
            @triggerScan()
            expect(@watcher.scan.calls.count()).toBe 1, 'multiple scans triggered right away'

            jasmine.clock().tick(99)
            expect(@watcher.scan.calls.count()).toBe 1, 'multiple scans triggered before interval is finished'

            jasmine.clock().tick(2)
            expect(@watcher.scan.calls.count()).toBe 2, 'multiple scans not triggered after interval'

          it 'invokes scan after the end of the throttle interval when invoked near the end of the interval', ->
            @triggerScan()
            expect(@watcher.scan.calls.count()).toBe 1, 'multiple scans triggered right away'

            jasmine.clock().tick(99)
            @triggerScan()
            expect(@watcher.scan.calls.count()).toBe 1, 'multiple scans triggered before interval is finished'

            jasmine.clock().tick(2)
            expect(@watcher.scan.calls.count()).toBe 2, 'multiple scans not triggered after interval'

          it 'coalesces repeated calls at each throttle interval', ->
            @triggerScan()
            @triggerScan()
            @triggerScan()

            jasmine.clock().tick(101)
            expect(@watcher.scan.calls.count()).toBe 2

          it 'does not continue to scan after repeated throttle intervals', ->
            @triggerScan()
            @triggerScan()
            @triggerScan()

            jasmine.clock().tick(101)
            expect(@watcher.scan.calls.count()).toBe 2

            jasmine.clock().tick(1000)
            expect(@watcher.scan.calls.count()).toBe 2

    describe '#withController', ->
      beforeEach ->
        @watcher = new Watcher ((name, el) -> return name)
        fixtures = fixture.set fullFixture, emptyFixture
        @fullComponent = fixtures[0][0]
        @emptyComponent = fixtures[1][0]

      it 'initializes the elements it receives', ->
        spyOn(@watcher, 'initialize').and.callThrough()
        @watcher.withController [@fullComponent, @emptyComponent], ->

        expect(@watcher.initialize.calls.count()).toBe 2

        args = @watcher.initialize.calls.allArgs()
        expect(args[0][0]).toBe @fullComponent
        expect(args[1][0]).toBe @emptyComponent

      it 'initializes a single element', ->
        spyOn(@watcher, 'initialize').and.callThrough()
        @watcher.withController @fullComponent, ->

        expect(@watcher.initialize.calls.count()).toBe 1
        expect(@watcher.initialize.calls.allArgs()[0][0]).toBe @fullComponent

      it 'invokes the callback with the elements passed in', (done) ->
        calls = []
        @watcher.withController [@fullComponent, @emptyComponent], (controller) ->
          calls.push controller

          # Make sure we were invoked for both components
          if calls.length == 2
            expect(calls).toContain('full')
            expect(calls).toContain('empty')

            done()

      it 'invokes the callback with a single element', (done) ->
        @watcher.withController @fullComponent, (controller) ->
          expect(controller).toBe 'full'
          done()

      it 'returns a promise which resolves when the callback has been invoked for all components', (done) ->
        calls = 0
        promise = @watcher.withController [@fullComponent, @emptyComponent], -> calls++
        promise.then ->
          expect(calls).toBe 2
          done()

    describe '#disconnect', ->
      beforeEach ->
        jasmine.clock().install()
      afterEach ->
        jasmine.clock().uninstall()
      it 'clears the interval if no observer present', ->
        watcher = new Watcher (->), MutationObserver: null, poll: 50
        spyOn watcher, 'scan'

        watcher.observe()
        jasmine.clock().tick(101)
        expect(watcher.scan.calls.count()).toBe 3 # Sanity check

        watcher.disconnect()
        jasmine.clock().tick(101)
        expect(watcher.scan.calls.count()).toBe 3

      it 'disconnects the observer', ->
        FakeObserver = class
          constructor: (handler) ->
            throw new Error('Expected only one call') if FakeObserver.instance?
            FakeObserver.instance = this
          observe: ->
          disconnect: ->
        watcher = new Watcher (->), MutationObserver: FakeObserver
        watcher.observe()

        expect(FakeObserver.instance).not.toBeUndefined() # Sanity
        spyOn(FakeObserver.instance, 'disconnect')

        watcher.disconnect()
        expect(FakeObserver.instance.disconnect.calls.count()).toBe 1

      it 'does not throw an error if called on a non-observing watcher', ->
        (new Watcher (->)).disconnect()
        expect(true).toBe true # Just want to make sure no error was thrown