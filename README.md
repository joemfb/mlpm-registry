##### mlpm-registry

package registry for mlpm (a MarkLogic package manager)

##### setup

    cp deploy/properties.template deploy/<env>.properties.template

and follow the steps in the comments

    cp run.sh.template run.sh
    chmod +x run.sh

Set the `PRIVILEGED_USER_PW` env variable to the same value as `appwriter-password` in `deploy/<env>.properties`.

To enable login via github OAUTH, register a new github application (https://github.com/settings/applications/new), then set the `GITHUB_*` env variables.

    ./ml <env> bootstrap
    ./ml <env> deploy modules
    ./run.sh

TODO: add sample data

##### license

- Copyright (c) 2014 Joseph Bryan. All Rights Reserved.
- Roxy: Copyright 2012 MarkLogic Corporation
- UI (based on https://github.com/marklogic/slush-marklogic-node): Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0]
(http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

The use of the Apache License does not indicate that this project is
affiliated with the Apache Software Foundation.
