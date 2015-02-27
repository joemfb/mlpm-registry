(function () {
  'use strict';

  angular.module('mlpm.docs')
    .controller('DocsCtrl', DocsCtrl);

  DocsCtrl.$inject = ['$scope', '$window'];

  function DocsCtrl($scope, $window) {
    var model = {
      origin: $window.location.origin
    };

    angular.extend($scope, {
      model: model
    });
  }
}());
