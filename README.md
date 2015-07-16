Regulator
=========
[![Build Status](https://travis-ci.org/AngelList/regulator.svg)](https://travis-ci.org/AngelList/regulator)
[![Sauce Test Status](https://saucelabs.com/browser-matrix/angellist-oss.svg)](https://saucelabs.com/u/angellist-oss)

Regulator is a tiny, opinionless tool for structuring your Javascript applications. We use it internally at
[AngelList](https://angel.co). It aims to keep you sane at any application scale.

Regulator weighs about 1.2KB (compressed). It requires a [Promises/A+](https://promisesaplus.com/) implementation.
It also optionally makes use of `MutationObserver` for reacting to changes in the DOM.

Motivation
----------

The world is filled with excellent Javascript frameworks, many of them full-featured and highly structured. Regulator is
extremely minimal, simply managing structured initialization of your components and allowing them to communicate with
each other. Perfect for loosely coupled applications at any scale, using any toolkit.

- **Automatic, tightly scoped initialization**

  Associate HTML elements directly with their Javascript behaviors, regardless of when or where they were added to the
  DOM. Automatically run initialization on server- and client-rendered content, without the need for context-specific
  setup.

- **Clean communication between components**

  Expose controllers for the logical pieces of your interface, and easily give them access to one another. Controllers
  can be built asynchronously, and can be anything from plain objects to Backbone views to Ember controllers.

Basic Usage
-----------

Denote components on your page with `data-wt`, and give them a name that describes how to initialize them:

```
<button data-wt="alert">Click me</button>
```

Create a `Regulator` instance and tell it how to initialize your components:

```
var myRegulator = new Regulator(function(name, el) {
  return require('initializers/' + name)(el);
}).observe();
```

```
// initializers/alert.js
module.exports = function(el) {
  var triggerAlert = function() { alert('clicked!') };
  el.onclick = triggerAlert;
  return { triggerAlert: triggerAlert }
};
```

Now whenever you add an element with `data-wt="popup"` to the DOM, a click listener will be bound:

```
var content = $.get(someUrl); // Contains a "popup" block
$('body').append(content); // "popup" block is initialized automatically
```

You can access the return value of the initialization function through your `Regulator` instance:

```
myRegulator.withController($("[data-wt='AlertButton']"), function(controller) {
  controller.triggerAlert();
});
```

API
---

##### Creating a `Regulator` instance

`new Regulator(initializer, options = {})`

Here `initializer` is a function which takes `(name, el)`, where `name` is the name of a component
and `el` is its root element. The return value of this function is referred to as the element's _controller_.

Available options are:

- `attribute`: The HTML attribute which denotes a component. _Default: `'data-wt'`
- `throttle`: When observing with a `MutationObserver`, the maximum frequency (in milliseconds) to call
  `#scan()`. _Default: `200`_
- `poll`: When observing in the absence of a `MutationObserver`, the interval to poll the DOM for changes.
  Set to `false` to disable the polling fallback. _Default: `1000`_
- `root`: Only components within this element will be initialized. _Default: `window.document.body`_
- `Promise`: The Promises/A+ implementation to use. _Default: `window.Promise`_
- `MutationObserver`: The MutationObserver implementation to use. _Default: `window.MutationObserver`_

##### Initializing your components

Depending on your use case, you can initialize your components in one of three ways:

`Regulator#initialize(element)`

Synchronously invokes the initializer for a single component. If called repeatedly, only invokes the initializer once.
Returns a `Promise` resolving to the element's controller.

`Regulator#scan()`

Synchronously finds and initializes all components which haven't been initialized yet. Returns a promise that resolves
when all initializations are complete.

`Regulator#observe()`

Observes the page for changes, and initializes new components as they're added. If `MutationObserver` is present,
uses it for relatively performant initialization; otherwise, falls back to `#scan` running repeatedly at the interval
specified by the `poll` option.

Regulator is optimized for fast detection of relevant changes to the DOM, but you should be aware of the performance
implications of `MutationObserver` or polling when using this option. You should also be aware that initialization
will occur asynchronously, at some point after elements have been added to the page. If you need finer-grained
control, use `#scan` or `#initialize`.

##### Accessing your controllers

`Regulator#withController(iterable, callback)`

Invokes `callback` with the controller for each component root in `iterable` (`iterable` can also be a single element).
Also initializes the components if they haven't been already.

Controllers can also be accessed through the return value of `#initialize`:
 
```
myRegulator.initialize(el).then(function(controller) {
  // ...
});
```

Testing
-------

Run tests using [karma](https://karma-runner.github.io):


```
$ npm install
$ node_modules/bin/karma start
```