(function () {
  'use strict';

  angular.module('mlpm.user')
    .controller('AccountCtrl', AccountCtrl);

  AccountCtrl.$inject = ['$scope', 'User', '$location'];

  function AccountCtrl($scope, user, $location) {
    var model = {
      user: user
    };

    if ( user.loaded && !user.authenticated ) {
      $location.path('/');
    }

    angular.extend($scope, {
      model: model
    });
  }

}());
