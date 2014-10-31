
angular.module('sample', [
  'ngRoute',
  'ngCkeditor',
  'ui.bootstrap',
  'gd.ui.jsonexplorer',
  'ml.common',
  'ml.search',
  'ml.search.tpls',
  'ml.utils',
  'sample.user',
  'sample.search',
  'sample.detail'
])
  .config(['$routeProvider', '$locationProvider', 'mlMapsProvider', function ($routeProvider, $locationProvider, mlMapsProvider) {

    'use strict';

    // use google maps, version 3, with the drawing and visualization libraries
    mlMapsProvider.useVersion(3);
    mlMapsProvider.addLibrary('drawing');
    mlMapsProvider.addLibrary('visualization');

    $locationProvider.html5Mode(true);

    $routeProvider
      .when('/', {
        templateUrl: '/search/search.html',
        controller: 'SearchCtrl',
        reloadOnSearch: false
      })
      .when('/detail', {
        templateUrl: '/detail/detail.html',
        controller: 'DetailCtrl'
      })
      .when('/profile', {
        templateUrl: '/user/profile.html',
        controller: 'ProfileCtrl'
      })
      .otherwise({
        redirectTo: '/'
      });
  }]);
