(function () {
  'use strict';

  angular.module('mlpm.search')
    .controller('SearchCtrl', SearchCtrl);

  SearchCtrl.$inject = ['$scope', '$location', 'MLSearchFactory'];

  function SearchCtrl($scope, $location, searchFactory) {
    var mlSearch = searchFactory.newContext(),
        model = {
          page: 1,
          qtext: '',
          search: {}
        };

    (function init() {
      mlSearch.addNamespace({ uri: 'http://mlpm.org/ns', prefix: 'mlpm' });

      mlSearch.fromParams().then(function() {
        updateSearchResults({});
        search();
      });

      $scope.$on('$locationChangeSuccess', function(e, newUrl, oldUrl){
        mlSearch.locationChange( newUrl, oldUrl ).then(function() {
          search();
        });
      });
    })();

    function updateSearchResults(data) {
      model.search = data;
      model.qtext = mlSearch.getText();
      model.page = mlSearch.getPage();

      $location.search( mlSearch.getParams() );
    }

    function search(qtext) {
      if ( arguments.length ) {
        model.qtext = qtext;
      }

      mlSearch
        .setText(model.qtext)
        .setPage(model.page)
        .search()
        .then(updateSearchResults);
    }

    angular.extend($scope, {
      model: model,
      search: search,
      suggest: function suggest(val) {
        return mlSearch.suggest(val).then(function(res) {
          return res.suggestions || [];
        });
      },
      toggleFacet: function toggleFacet(facetName, value) {
        mlSearch
          .toggleFacet( facetName, value )
          .search()
          .then(updateSearchResults);
      },
      linkTarget: function(result) {
        var prefix = '/package/';
        return prefix + result.metadata[ 'mlpm:name' ].values[0];
      }
    });

  }

}());
