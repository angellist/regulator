watcher
=======
[![Build Status](https://travis-ci.org/venturehacks/watcher.svg)](https://travis-ci.org/venturehacks/watcher)

Watcher is a tiny opinionless Javascript application framework. It weighs about 1.2KB (compressed).

It requires a [Promises/A+](https://promisesaplus.com/) implementation. It also optionally makes use of
`MutationObserver` for reacting to changes in the DOM.

Motivation
----------

The world is filled with excellent Javascript frameworks, many of them full-featured and highly structured. Watcher is
extremely minimal, simply managing structured initialization of your components and allowing them to communicate with
each other. Perfect for loosely coupled applications at any scale, or applications that prefer to define their own
structure and toolkit.

- **Automatic, tightly scoped initialization**

  Associate HTML elements directly with their Javascript behaviors, regardless of when or where they were added to the
  DOM. Easily isolate the initialization of components on the page.

- **Clean communication between components**

  Expose controllers for the logical pieces of your interface, and easily give them access to one another. Controllers
  can be built asynchronously, and can be anything from plain objects to Backbone views to Ember controllers.

Usage
-----

Denote components on your page with `data-wt`, and give them a name that describes how to initialize them:

```
<div data-wt="popup">
  Click me
</div>
```

Create a `Watcher` instance and tell it how to initialize your components:

```
var Initializers = {
  popup: function(el) { 
    $(el).on('click', function() { 
      alert('clicked'); 
    });
  },
  foo: function(el) { 
    // ...
  }
};

new Watcher(function(name, el) {
  // In a more complex application, you'd likely choose something like `require('components/' + name)(el);`
  return Initializers[name](el);
}).observe();
```

Now whenever you add an element with `data-wt="popup"` to the DOM, it will be automatically initialized:

```
var content = $.get(someUrl); // Contains a "popup" block
$('body').append(content); // "popup" block is initialized automatically
```

Testing
-------

Run tests using [karma](https://karma-runner.github.io):


```
$ npm install
$ node_modules/bin/karma start
```