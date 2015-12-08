# godep-licenses

Godep dependency license report generation tool


## Dependencies

The following dependencies must be installed locally to use godep-license, unless you use the docker image.

- [Ninka](http://ninka.turingmachine.org) - License identification tool
- [jpq](https://stedolan.github.io/jq/) - command-line json processor


## Build

```
docker build -t mesosphere/godep-licenses .
```


## Example Usage

Markdown (with exemptions):

```
docker run --rm -i -v "$(pwd):/repo" mesosphere/godep-licenses:latest -p /repo \
  -e github.com/abbot/go-http-auth:Apache-2 \
  -e github.com/beorn7/perks/quantile:MIT? \
  -e github.com/daviddengcn/go-colortext:BSD? \
  -e github.com/shurcooL/sanitized_anchor_name:MIT? \
  -e github.com/spf13/cobra:Apache-2 \
  -e github.com/stretchr/objx:MIT? \
  -e github.com/stretchr/testify:MIT? \
  -o md > Godeps/LICENSES.md
```

Comma Separated Values (without exemptions):

```
docker run --rm -i -v "$(pwd):/repo" mesosphere/godep-licenses:latest -p /repo \
  -o csv > Godeps/LICENSES.csv
```


## License

Copyright 2015 Mesosphere

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
