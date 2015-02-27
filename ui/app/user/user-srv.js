(function () {
  'use strict';

  angular.module('mlpm.user')
    .factory('User', ['$http', function($http) {
      var user = {};

      init();

      $http.get('/user/status', {}).then(function (response) {
        user.loaded = true;
        user.authenticated = response.data.authenticated;
        _.merge(user, response.data.user);
      });

      function init() {
        _.merge(user, {
          name: '',
          username: '',
          authenticated: false,
          'github-data': {},
          //TODO: ?
          loginError: false
        });
      }

      angular.extend(user, {
        logout: function() {
          $http.get('/user/logout').then(init);
        }
      });

      return user;
    }]);
}());
