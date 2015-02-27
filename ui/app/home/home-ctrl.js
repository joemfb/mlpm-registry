(function () {
  'use strict';

  angular.module('mlpm.home')
    .controller('HomeCtrl', HomeCtrl);

  HomeCtrl.$inject = ['$scope'];

  function HomeCtrl($scope) {
    var model = {
      detail: {}
    };

    angular.extend($scope, {
      model: model
    });
  }
}());
