(function () {
  'use strict';

  angular.module('mlpm.user')
    .controller('AccountCtrl', ['$scope', 'User', '$location', function ($scope, user, $location) {
      var model = {
        user: user
      };

      if ( user.loaded && !user.authenticated ) {
        $location.path('/');
      }

      angular.extend($scope, {
        model: model
      });
    }]);
}());
