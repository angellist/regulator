# Our async specs are close to synchronous
jasmine.DEFAULT_TIMEOUT_INTERVAL = 500

allTestFiles = []
POLYFILL_REGEXP = /(dist\/es6-promise)(\.js)$/
TEST_REGEXP = /(spec|test)(\.coffee)?(\.js)?$/i
pathToModule = (path) ->
  path.replace(/^\/base\//, "").replace(/\.js$/, "").replace(/\.coffee$/, "")

Object.keys(window.__karma__.files).forEach (file) ->
  # Normalize paths to RequireJS module names.
  allTestFiles.push pathToModule(file) if TEST_REGEXP.test(file) || POLYFILL_REGEXP.test(file)
  return

require.config
  # Karma serves files under /base, which is the basePath from your config file
  baseUrl: "/base"

  # dynamically load all test files
  deps: allTestFiles

  # we have to kickoff jasmine, as it is asynchronous
  callback: (args...) ->
    require('node_modules/es6-promise/dist/es6-promise').polyfill()
    window.__karma__.start.apply this, args
