# Our async specs are close to synchronous
jasmine.DEFAULT_TIMEOUT_INTERVAL = 500

allTestFiles = []
TEST_REGEXP = /(spec|test)(\.coffee)?(\.js)?$/i
pathToModule = (path) ->
  path.replace(/^\/base\//, "").replace(/\.js$/, "").replace(/\.coffee$/, "")

for file of window.__karma__.files
  # Normalize paths to RequireJS module names.
  allTestFiles.push pathToModule(file) if TEST_REGEXP.test(file)

require.config
  # Karma serves files under /base, which is the basePath from your config file
  baseUrl: "/base"

  # dynamically load all test files
  deps: ['node_modules/es6-promise/dist/es6-promise'].concat(allTestFiles)

  # we have to kickoff jasmine, as it is asynchronous
  callback: (es6Promise, args...) ->
    es6Promise.polyfill()
    window.__karma__.start.apply this, args
