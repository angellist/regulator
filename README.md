watcher
=======

A tiny opinionless Javascript framework.

Usage
-----

Denote initializable blocks in your document with `data-watcher-name`:

```
<div data-watcher-name="toggle" />
  <a href="#" class="visible">Click me!</a>
  <a href="#" class="hidden">No, click ME!</a>
</div>
```

Create a `Watcher` instance and tell it how to initialize your blocks:

```
var Initializers = {
  // This function will be invoked once with each element whose `data-watcher-name` is "toggle"
  toggle: function(el) {
    $(el).on('click', 'a.visible', function() {
      var hidden = $(el).find('.hidden');
      $(el).find('.visible').removeClass('visible').addClass('hidden');
      hidden.removeClass('hidden').addClass('visible');
    });
  }
  
  foo: function(el) { 
    // ...
  }
};

var initializer = function(name) { Initializers[name]; };
var watcher = new Watcher({initializer: initializer});
watcher.observe();
```

Whenever you add another block with `data-watcher-name="toggle"` to the DOM, 
it will be automatically initialized:

```
var content = $.get(someUrl); // Contains a "toggle" block
$('body').append(content); // "toggle" block is initialized automatically
```
