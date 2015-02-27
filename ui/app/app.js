
angular.module('mlpm', [
  'ngRoute',
  'ngCkeditor',
  'ui.bootstrap',
  'ml.common',
  'ml.search',
  'ml.search.tpls',
  'mlpm.user',
  'mlpm.search',
  'mlpm.package',
  'mlpm.docs',
  'mlpm.home'
])
  .config(['$routeProvider', '$locationProvider', function ($routeProvider, $locationProvider) {

    'use strict';

    $locationProvider.html5Mode(true);

    $routeProvider
      .when('/', {
        templateUrl: '/home/home.html',
        controller: 'HomeCtrl'
      })
      .when('/search', {
        templateUrl: '/search/search.html',
        controller: 'SearchCtrl',
        reloadOnSearch: false
      })
      .when('/docs', {
        templateUrl: '/docs/docs.html',
        controller: 'DocsCtrl'
      })
      .when('/account', {
        templateUrl: '/user/account.html',
        controller: 'AccountCtrl'
      })
      .when('/package/:package', {
        templateUrl: '/package/package.html',
        controller: 'PackageCtrl'
      })
      .otherwise({
        redirectTo: '/'
      });
  }]);
