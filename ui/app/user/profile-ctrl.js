(function () {
  'use strict';

  angular.module('mlpm.user')
    .controller('ProfileCtrl', ProfileCtrl);

  ProfileCtrl.$inject = ['$scope', 'MLRest', '$routeParams'];

  function ProfileCtrl($scope, mlRest, $routeParams) {
    var model = {
      detail: {}
    };

    mlRest.extension('user', {
      params: { 'rs:username': $routeParams.user }
    }).then(function(response) {
      model.detail = response.data;
    });

    angular.extend($scope, {
      model: model
    });
  }
}());
