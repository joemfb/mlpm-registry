(function () {
  'use strict';

  angular.module('mlpm.package')
    .controller('PackageCtrl', ['$scope', 'MLRest', '$routeParams', function ($scope, mlRest, $routeParams) {
      var uri = $routeParams.uri;
      var model = {
        // your model stuff here
        detail: {}
      };

      function getPackage(uri) {
        mlRest.getDocument(uri, {
          format: 'json',
          transform: 'mlpm'
        }).then(function(response) {
          model.detail = response.data;
        });
      }

      mlRest.search({
        q: 'name:' + $routeParams.package,
        options: 'all',
        pageLength: 1
      }).then(function(response) {
        // TODO: redirect to 404 page
        if (response.data.total !== 1) return console.log('error')

        getPackage(response.data.results[0].uri)
      })



      angular.extend($scope, {
        model: model

      });
    }]);
}());
