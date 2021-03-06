(function () {
  'use strict';

  angular.module('mlpm.home')
    .controller('HomeCtrl', HomeCtrl);

  HomeCtrl.$inject = ['$scope', 'MLRest'];

  function HomeCtrl($scope, MLRest) {
    var model = {
      commonDependencies: []
    };

    MLRest.values('dependency', {
      options: 'all',
      structuredQuery: JSON.stringify({
        search: { query: { 'and-query': [
          { 'collection-query': { uri: 'http://mlpm.org/ns/collection/package' } },
          { 'collection-query': { uri: 'http://mlpm.org/ns/collection/published' } }
        ] } }
      })
    }).then(function(response) {
      model.commonDependencies = response.data['values-response']['distinct-value'];
    });

    angular.extend($scope, {
      model: model
    });
  }
}());
