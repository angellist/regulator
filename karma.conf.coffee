# Karma configuration

require('dotenv').load()
module.exports = (config) ->

  customLaunchers = {}
  for browser in ['chrome', 'firefox', 'safari']
    customLaunchers["sl_#{browser}"] = {
      base: 'SauceLabs'
      browserName: browser
      platform: 'OS X 10.10'
    }
  for version in ['11', '10', '9', '8']
    customLaunchers["sl_ie_#{version}"] = {
      base: 'SauceLabs'
      browserName: 'internet explorer'
      version: "#{version}.0"
    }
  customLaunchers['sl_opera'] = {base: 'SauceLabs', browserName: 'opera'}
  config.set

    # base path that will be used to resolve all patterns (eg. files, exclude)
    basePath: '.'


    # frameworks to use
    # available frameworks: https://npmjs.org/browse/keyword/karma-adapter
    frameworks: ['jasmine', 'requirejs', 'fixture']


    # list of files / patterns to load in the browser
    files: [
      'spec/test-main.coffee'
      {pattern: 'spec/favicon.ico', included: false, served: true} # Otherwise we get 404 warnings
      {pattern: 'node_modules/es6-promise/dist/es6-promise.js', included: false}
      {pattern: 'src/**/*.coffee', included: false}
      {pattern: 'spec/**/*.spec.coffee', included: false}
    ]
    proxies: {
      '/favicon.ico': '/base/spec/favicon.ico'
    }


    # list of files to exclude
    exclude: [
    ]


    # preprocess matching files before serving them to the browser
    # available preprocessors: https://npmjs.org/browse/keyword/karma-preprocessor
    preprocessors: {
      '**/*.coffee': ['coffee']
    }


    # test results reporter to use
    # possible values: 'dots', 'progress'
    # available reporters: https://npmjs.org/browse/keyword/karma-reporter
    reporters: ['progress', 'saucelabs']


    # web server port
    port: 9876


    # enable / disable colors in the output (reporters and logs)
    colors: true


    # level of logging
    # possible values:
    # - config.LOG_DISABLE
    # - config.LOG_ERROR
    # - config.LOG_WARN
    # - config.LOG_INFO
    # - config.LOG_DEBUG
    logLevel: config.LOG_INFO


    # enable / disable watching file and executing tests whenever any file changes
    autoWatch: true


    # start these browsers
    # available browser launchers: https://npmjs.org/browse/keyword/karma-launcher
    browsers: Object.keys(customLaunchers)


    # Continuous Integration mode
    # if true, Karma captures browsers, runs the tests and exits
    singleRun: true


    # Custom config for Sauce testing
    captureTimeout: 120000
    customLaunchers: customLaunchers
    sauceLabs: {
      testName: 'Watcher'
    }

